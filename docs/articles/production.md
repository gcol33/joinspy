# Joins in Production

Interactive analysis and production scripts have different failure
modes. When you explore data at the console, a bad join is annoying but
recoverable: you see the wrong row count, swear, fix the key, and
re-run. In a scheduled script that feeds a dashboard or triggers
downstream jobs, that same bad join silently corrupts everything it
touches. Nobody notices until a stakeholder files a ticket three weeks
later.

joinspy was built with both contexts in mind, but this vignette focuses
exclusively on the second one: wiring joinspy into automated pipelines
so that join problems surface as errors or log entries rather than
silent data corruption. Every example here uses synthetic data and
[`tempfile()`](https://rdrr.io/r/base/tempfile.html) paths, so you can
run the vignette end to end without touching your filesystem.

## Assertions with key_check()

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
returns a single logical: `TRUE` if no issues were detected, `FALSE`
otherwise. That makes it a natural fit for assertions. The simplest
pattern wraps it in
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html):

``` r

orders <- data.frame(
  customer_id = c("C01", "C02", "C03", "C04"),
  amount = c(100, 200, 150, 300),
  stringsAsFactors = FALSE
)

customers <- data.frame(
  customer_id = c("C01", "C02", "C03", "C04"),
  region = c("East", "West", "East", "North"),
  stringsAsFactors = FALSE
)

# This passes -- keys are clean
stopifnot(key_check(orders, customers, by = "customer_id", warn = FALSE))
```

When the keys have problems, the script halts:

``` r

orders_dirty <- data.frame(
  customer_id = c("C01", "C02 ", "C03 ", "C04"),
  amount = c(100, 200, 150, 300),
  stringsAsFactors = FALSE
)

stopifnot(key_check(orders_dirty, customers, by = "customer_id", warn = FALSE))
#> Error:
#> ! key_check(orders_dirty, customers, by = "customer_id", warn = FALSE) is not TRUE
```

The `warn = FALSE` argument suppresses the printed diagnostics. In a
cron job or CI pipeline, you generally want the script to fail hard and
fast rather than print warnings that nobody reads. If you need more
control over the error message, use an explicit `if`/`stop` pattern
instead:

``` r

if (!key_check(orders_dirty, customers, by = "customer_id", warn = FALSE)) {
  stop("Key quality check failed for orders-customers join. ",
       "Run join_spy() interactively for details.", call. = FALSE)
}
#> Error:
#> ! Key quality check failed for orders-customers join. Run join_spy() interactively for details.
```

This is more verbose but gives you a custom error message that can
include the table names, the pipeline step, or a link to documentation.
You choose the tradeoff.

A common pattern chains the assertion with a repair step. Run
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
first; if it fails, repair and re-check:

``` r

ok <- key_check(orders_dirty, customers, by = "customer_id", warn = FALSE)

if (!ok) {
  repaired <- join_repair(
    orders_dirty, customers,
    by = "customer_id",
    trim_whitespace = TRUE,
    remove_invisible = TRUE
  )
  orders_clean <- repaired$x
  customers_clean <- repaired$y

  # Re-check after repair
  stopifnot(key_check(orders_clean, customers_clean,
                       by = "customer_id", warn = FALSE))
}
#> ✔ Repaired 2 value(s)
```

When should you use
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
versus
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)?
They serve different roles.
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
is a gate, a binary pass/fail that costs almost nothing to run.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
is a detailed diagnostic that builds a full report object with match
rates, expected row counts, and categorized issues. In a production
script,
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
is the assertion you run on every execution;
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
is what you pull out when the assertion fails and you need to understand
why. Calling
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
on every run is fine for moderate-sized tables, but for million-row
datasets the overhead adds up, and
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
is the leaner choice.

## Silent Joins in Pipelines

The `*_join_spy()` wrappers print diagnostic output by default. That
output is helpful when you are working interactively; it is noise in a
scheduled script. The `.quiet = TRUE` argument suppresses all printed
output while still computing and storing the diagnostic report
internally.

``` r

sensors <- data.frame(
  sensor_id = c("S01", "S02", "S03", "S04"),
  location = c("Roof", "Basement", "Lobby", "Garage"),
  stringsAsFactors = FALSE
)

readings <- data.frame(
  sensor_id = c("S01", "S02", "S03", "S05"),
  temperature = c(22.1, 18.5, 21.0, 19.3),
  stringsAsFactors = FALSE
)

# Nothing printed
result <- left_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)
```

The report is still available after the fact via
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md):

``` r

rpt <- last_report()
rpt$match_analysis$match_rate
#> [1] 0.75
```

This separation of execution and inspection is the key pattern. The join
runs silently inside a pipeline. Later (maybe in a validation step at
the end of the script, maybe in a separate monitoring job) you pull the
report and check its contents programmatically:

``` r

rpt <- last_report()
if (rpt$match_analysis$match_rate < 0.95) {
  warning(sprintf(
    "Low match rate (%.1f%%) in sensor join -- check for missing sensor IDs",
    rpt$match_analysis$match_rate * 100
  ))
}
#> Warning: Low match rate (75.0%) in sensor join -- check for missing sensor IDs
```

This gives you the diagnostic power of
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
without cluttering the standard output of your pipeline. The report
object persists in memory until the next `*_join_spy()` call overwrites
it, so there is no race condition as long as your script is
single-threaded (which R scripts are).

You can build arbitrarily complex validation logic on top of the report
object. Check the number of issues, inspect specific issue types,
compare the expected row count against a threshold; whatever your
pipeline requires. The report is a plain list, so standard R subsetting
works. Nothing about the validation requires interactive use; it is all
programmatic.

One caveat:
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
only stores the single most recent report. If your script performs three
joins in sequence, only the third report survives. If you need to retain
reports from earlier joins, either log them (see the next section) or
capture them explicitly:

``` r

result1 <- left_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)
report1 <- last_report()

# ... later ...
result2 <- inner_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)
report2 <- last_report()
```

## Cardinality Guards

A join that was one-to-one in development can become many-to-many in
production when upstream data changes.
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
prevents this by enforcing a cardinality constraint. If the constraint
is violated, the function throws an error instead of silently producing
a Cartesian product.

The workflow has two phases. In development, you use
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
to understand the actual relationship:

``` r

products <- data.frame(
  product_id = c("P1", "P2", "P3"),
  name = c("Widget", "Gadget", "Gizmo"),
  stringsAsFactors = FALSE
)

line_items <- data.frame(
  product_id = c("P1", "P1", "P2", "P3", "P3"),
  order_id = c(101, 102, 103, 104, 105),
  stringsAsFactors = FALSE
)

detect_cardinality(products, line_items, by = "product_id")
#> ℹ Detected cardinality: "1:m"
#> Right duplicates: 2 key(s)
```

The result tells you this is a one-to-many relationship: each product
appears once in `products` but can appear multiple times in
`line_items`. That is expected because products are a reference table
and line items are transactional. Now you encode that expectation in
production:

``` r

result <- join_strict(
  products, line_items,
  by = "product_id",
  type = "left",
  expect = "1:m"
)
nrow(result)
#> [1] 5
```

If someone accidentally loads a `products` table with duplicate product
IDs (turning the relationship into many-to-many), the script fails
immediately:

``` r

products_bad <- data.frame(
  product_id = c("P1", "P1", "P2", "P3"),
  name = c("Widget", "Widget v2", "Gadget", "Gizmo"),
  stringsAsFactors = FALSE
)

join_strict(
  products_bad, line_items,
  by = "product_id",
  type = "left",
  expect = "1:m"
)
#> Error:
#> ! Cardinality violation: expected 1:m but found m:m
#>   Left duplicates: 1, Right duplicates: 2
```

The four cardinality levels each correspond to a real data pattern:

- **1:1** means a lookup table joined to another lookup table. Each key
  appears exactly once on both sides (country codes to currency codes,
  employee IDs to badge numbers). If either side has duplicates,
  something went wrong in the ETL.

- **1:m** applies when the left table is a reference and the right table
  has transactions or measurements: products to order line items,
  customers to support tickets, stations to hourly weather readings.

- **m:1** is the mirror image: the left table has transactions while the
  right table serves as the lookup. Examples include sales records
  joined to a region table, or survey responses joined to a demographic
  codebook.

- **m:m** indicates duplicates on both sides. This is almost always a
  bug. The only legitimate use case is generating all pairwise
  combinations of two attribute sets, which is rare enough that
  requiring an explicit `expect = "m:m"` acts as a speed bump.

In practice, `"1:m"` and `"m:1"` cover the vast majority of production
joins. Use
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
once during development to confirm the relationship, then hard-code the
`expect` value in your production script. The constraint costs almost
nothing at runtime (it checks for duplicates in the key columns before
performing the join) yet it catches a class of upstream data quality
problems that would otherwise propagate silently.

Why not just use
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
instead? The two functions solve different problems.
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
warns about Cartesian product explosion, the situation where a key has
many duplicates on both sides and the join result grows quadratically.
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
enforces a relationship contract. A join can violate a `"1:1"`
constraint without triggering a Cartesian explosion (one extra duplicate
is enough). Conversely, a `"m:m"` join can produce a massive Cartesian
product that
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
would allow because `"m:m"` is the loosest constraint. Use
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
when you know the expected relationship. Use
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
as an additional guard when the expected relationship is `"m:m"` and you
want to bound the expansion factor.

## Logging and Audit Trails

Production scripts need logs. joinspy provides two mechanisms: manual
logging with
[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
and automatic logging with
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md).

### Manual logging

[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
writes a single report to a file. The format depends on the file
extension:

``` r

report <- join_spy(sensors, readings, by = "sensor_id")

# Text format -- human-readable
txt_log <- tempfile(fileext = ".log")
log_report(report, txt_log)
#> ✔ Report logged to C:/Temp\RtmpKCPMYC\file1d9003e615f06.log
cat(readLines(txt_log), sep = "\n")
#> Logged: 2026-03-31 09:32:44
#> ------------------------------------------------------------
#> Join Key: sensor_id
#> 
#> Left Table (x):
#>   Rows: 4
#>   Unique keys: 4
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Right Table (y):
#>   Rows: 4
#>   Unique keys: 4
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Match Analysis:
#>   Keys in both: 3
#>   Keys only in left: 1
#>   Keys only in right: 1
#>   Match rate: 75%
#> 
#> Expected Rows:
#>   inner_join: 3
#>   left_join: 4
#>   right_join: 4
#>   full_join: 5
#> 
#> Issues Detected: 1
#>   near_match: 1
#> ============================================================
unlink(txt_log)
```

``` r

# JSON format -- machine-readable
json_log <- tempfile(fileext = ".json")
log_report(report, json_log)
#> ✔ Report logged to C:/Temp\RtmpKCPMYC\file1d90043297cf9.json
cat(readLines(json_log), sep = "\n")
#> {
#>   "by": "sensor_id",
#>   "x_summary": {
#>   "n_rows": 4,
#>   "n_unique": 4,
#>   "n_duplicated": null,
#>   "n_na": 0
#> },
#>   "y_summary": {
#>   "n_rows": 4,
#>   "n_unique": 4,
#>   "n_duplicated": null,
#>   "n_na": 0
#> },
#>   "match_analysis": {
#>   "n_matched": 3,
#>   "n_left_only": 1,
#>   "n_right_only": 1,
#>   "match_rate": 0.75
#> },
#>   "expected_rows": {
#>   "inner": 3,
#>   "left": 4,
#>   "right": 4,
#>   "full": 5
#> },
#>   "n_issues": 1,
#>   "issue_types": "near_match",
#>   "logged_at": "2026-03-31 09:32:44"
#> }
unlink(json_log)
```

Text format is useful when humans read the logs directly: tailing a log
file during a batch run, reviewing output after a nightly job. JSON
format is useful when the logs feed into a monitoring system, a
database, or a downstream script that parses them programmatically. Pick
one based on who or what will consume the log.

You can also save reports as `.rds` files, which preserves the full R
object including all nested lists and data frames. This is heavier than
text or JSON but allows you to reload the report later and inspect it
interactively with [`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html), or direct list
access. Use `.rds` when you need the complete report for post-mortem
analysis; use text or JSON when you need a human-readable or
machine-parseable record.

### Automatic logging

For scripts that perform many joins, setting up a log file once at the
top is cleaner than calling
[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
after each join.
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
enables automatic logging: every subsequent `*_join_spy()` call appends
its report to the specified file.

``` r

auto_log <- tempfile(fileext = ".log")
set_log_file(auto_log, format = "text")
#> ℹ Automatic logging enabled: C:/Temp\RtmpKCPMYC\file1d90018b05631.log

# These joins are automatically logged
result1 <- left_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)
result2 <- inner_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)

# Check what got logged
cat(readLines(auto_log), sep = "\n")
#> 
#> Logged: 2026-03-31 09:32:44
#> ------------------------------------------------------------
#> Join Key: sensor_id
#> 
#> Left Table (x):
#>   Rows: 4
#>   Unique keys: 4
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Right Table (y):
#>   Rows: 4
#>   Unique keys: 4
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Match Analysis:
#>   Keys in both: 3
#>   Keys only in left: 1
#>   Keys only in right: 1
#>   Match rate: 75%
#> 
#> Expected Rows:
#>   inner_join: 3
#>   left_join: 4
#>   right_join: 4
#>   full_join: 5
#> 
#> Issues Detected: 1
#>   near_match: 1
#> ============================================================
#> 
#> Logged: 2026-03-31 09:32:44
#> ------------------------------------------------------------
#> Join Key: sensor_id
#> 
#> Left Table (x):
#>   Rows: 4
#>   Unique keys: 4
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Right Table (y):
#>   Rows: 4
#>   Unique keys: 4
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Match Analysis:
#>   Keys in both: 3
#>   Keys only in left: 1
#>   Keys only in right: 1
#>   Match rate: 75%
#> 
#> Expected Rows:
#>   inner_join: 3
#>   left_join: 4
#>   right_join: 4
#>   full_join: 5
#> 
#> Issues Detected: 1
#>   near_match: 1
#> ============================================================

# Clean up
set_log_file(NULL)
#> ℹ Automatic logging disabled
unlink(auto_log)
```

The pattern for a production script is: set up the log file at the
start, run all your joins, and disable logging at the end (or let R’s
session cleanup handle it). The log accumulates a timestamped record of
every join, including match rates, issue counts, and expected row
counts. If something goes wrong downstream, you can trace back through
the log to see which join introduced the problem.

Automatic logging only triggers from `*_join_spy()` wrappers. If you
call
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
or bare [`merge()`](https://rdrr.io/r/base/merge.html) directly, nothing
is logged. This is by design: the wrappers are the “instrumented” path,
and
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
is a lightweight guard that does not build a full report. If you want
both cardinality enforcement and logging, run
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
as a separate check, then use
[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)
(or whichever wrapper fits) for the actual join. The complete production
pattern at the end of this vignette demonstrates exactly this approach.

[`get_log_file()`](https://gillescolling.com/joinspy/reference/get_log_file.md)
returns the current log path (or `NULL` if logging is disabled), which
is handy for conditional logic:

``` r

# Only log if logging is configured
if (!is.null(get_log_file())) {
  message("Logging is active at: ", get_log_file())
}
```

## Sampling for Large Datasets

Running full diagnostics on a table with ten million rows takes time.
The `sample` parameter in
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
runs the analysis on a random subset while the actual join (if you use a
`*_join_spy()` wrapper) still operates on the full data.

``` r

# Simulate a large dataset
set.seed(42)
big_orders <- data.frame(
  customer_id = sample(paste0("C", sprintf("%04d", 1:5000)), 50000, replace = TRUE),
  amount = round(runif(50000, 10, 500), 2),
  stringsAsFactors = FALSE
)

big_customers <- data.frame(
  customer_id = paste0("C", sprintf("%04d", 1:6000)),
  region = sample(c("North", "South", "East", "West"), 6000, replace = TRUE),
  stringsAsFactors = FALSE
)

# Full analysis
system.time(report_full <- join_spy(big_orders, big_customers, by = "customer_id"))
#>    user  system elapsed 
#>    0.14    0.03    0.18

# Sampled analysis
system.time(report_sampled <- join_spy(big_orders, big_customers,
                                        by = "customer_id", sample = 5000))
#>    user  system elapsed 
#>    0.07    0.02    0.09
```

The sampled report is approximate. Match rates and duplicate counts are
estimated from the sample rather than computed exactly. For most
production monitoring, this is fine; you want to know whether the match
rate is roughly 95% or roughly 60%, not whether it is 94.7% or 95.1%.
The sample catches systemic problems (wrong key column, widespread
encoding issues, massive duplicate explosion) with a fraction of the
runtime.

The tradeoff: sampling can miss rare issues. If 0.1% of your keys have a
zero-width space, a 5,000-row sample from a 10-million-row table might
not include any of them. For this reason, run full diagnostics
periodically (weekly, or whenever the upstream data source changes) and
use sampled diagnostics for the daily runs. This layered approach gives
you speed on most executions and thoroughness when it matters.

How large should the sample be? There is no universal answer, but a
sample of 10,000 to 50,000 rows catches most systemic issues. The goal
is not statistical significance; it is catching problems that affect a
meaningful fraction of keys. If your pipeline joins ten tables, sampling
each one at 10,000 rows keeps the total diagnostic overhead under a
second even on modest hardware. The diagnostics are always cheaper than
the join itself, so the sample size rarely needs to be tuned
aggressively.

## A Complete Production Pattern

The sections above introduced each tool individually. Here they are
wired together into a single script that represents a realistic
production workflow. The scenario: a nightly job loads order and
customer data, validates keys, repairs if needed, joins with cardinality
enforcement, and logs everything for audit.

``` r

# ============================================================
# Nightly order enrichment pipeline
# ============================================================

# --- Setup logging ---
pipeline_log <- tempfile(fileext = ".log")
set_log_file(pipeline_log, format = "text")
#> ℹ Automatic logging enabled: C:/Temp\RtmpKCPMYC\file1d900356337fa.log

# --- Load data (simulated) ---
orders <- data.frame(
  order_id = 1:6,
  customer_id = c("C001", "C002 ", "C003", "C003", "C004", "C005"),
  amount = c(150, 230, 89, 410, 320, 175),
  stringsAsFactors = FALSE
)

customers <- data.frame(
  customer_id = c("C001", "C002", "C003", "C004", "C005", "C006"),
  name = c("Acme Corp", "Globex", "Initech", "Umbrella", "Soylent", "Wonka"),
  tier = c("gold", "silver", "gold", "bronze", "silver", "gold"),
  stringsAsFactors = FALSE
)

# --- Gate 1: key quality assertion ---
keys_ok <- key_check(orders, customers, by = "customer_id", warn = FALSE)

if (!keys_ok) {
  message("Key issues detected -- attempting repair")
  repaired <- join_repair(
    orders, customers,
    by = "customer_id",
    trim_whitespace = TRUE,
    remove_invisible = TRUE
  )
  orders <- repaired$x
  customers <- repaired$y
}
#> Key issues detected -- attempting repair
#> ✔ Repaired 1 value(s)

# --- Gate 2: cardinality check ---
card <- detect_cardinality(orders, customers, by = "customer_id")
#> ℹ Detected cardinality: "m:1"
#> Left duplicates: 1 key(s)
if (card == "m:m") {
  set_log_file(NULL)
  unlink(pipeline_log)
  stop("Unexpected m:m cardinality in orders-customers join", call. = FALSE)
}

# --- Join (with auto-logging via *_join_spy) ---
enriched <- left_join_spy(orders, customers, by = "customer_id", .quiet = TRUE)

# --- Gate 3: row count sanity check ---
# A left join should never lose rows from the left table
if (nrow(enriched) < nrow(orders)) {
  set_log_file(NULL)
  unlink(pipeline_log)
  stop("Row count decreased after left join -- possible data corruption",
       call. = FALSE)
}

# --- Output ---
message(sprintf("Pipeline complete: %d enriched orders", nrow(enriched)))
#> Pipeline complete: 6 enriched orders
head(enriched)
#>   customer_id order_id amount      name   tier
#> 1        C001        1    150 Acme Corp   gold
#> 2        C002        2    230    Globex silver
#> 3        C003        3     89   Initech   gold
#> 4        C003        4    410   Initech   gold
#> 5        C004        5    320  Umbrella bronze
#> 6        C005        6    175   Soylent silver

# --- Review the log ---
if (file.exists(pipeline_log)) {
  cat(readLines(pipeline_log), sep = "\n")
}
#> 
#> Logged: 2026-03-31 09:32:44
#> ------------------------------------------------------------
#> Join Key: customer_id
#> 
#> Left Table (x):
#>   Rows: 6
#>   Unique keys: 5
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Right Table (y):
#>   Rows: 6
#>   Unique keys: 6
#>   Duplicated keys: 
#>   NA keys: 0
#> 
#> Match Analysis:
#>   Keys in both: 5
#>   Keys only in left: 0
#>   Keys only in right: 1
#>   Match rate: 100%
#> 
#> Expected Rows:
#>   inner_join: 6
#>   left_join: 6
#>   right_join: 7
#>   full_join: 7
#> 
#> Issues Detected: 1
#>   duplicates: 1
#> ============================================================

# --- Cleanup ---
set_log_file(NULL)
#> ℹ Automatic logging disabled
unlink(pipeline_log)
```

Each gate in this script serves a different purpose. The
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
gate catches string-level problems (whitespace, encoding, case) and
attempts an automatic repair. The
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
gate checks the relationship between the two tables: orders to customers
should be many-to-one, and if the customer table suddenly has duplicates
(a common ETL failure), the script halts before producing a Cartesian
product. The row count check is a final sanity guard: a left join should
preserve all rows from the left table, and if it does not, something has
gone wrong that the other gates did not catch.

The logging runs in the background throughout because
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
was called at the top. Every `*_join_spy()` call appends a timestamped
report to the log file. After the script finishes, the log contains a
complete record of every join: what was checked, what was found, and
what the predicted row counts were. This audit trail pays for itself
when debugging a data quality issue days after the pipeline ran.

The pattern scales. Add more tables, more gates, more joins, and the
structure stays the same. Set up logging once, assert key quality before
each join, enforce cardinality where you know the expected relationship,
and check row counts after. The overhead is minimal:
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
and
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
are both O(n) in the number of rows, and
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
adds only a duplicate check on top of the join itself. For million-row
tables, add `sample = 50000` to the
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
calls if the diagnostics become the bottleneck.

The alternative to all of this is trust. Trust that the upstream data is
clean, trust that the ETL did not introduce duplicates, trust that the
key columns still match. Trust works until it does not, and when it
breaks, the cost is always higher than the cost of the checks would have
been.
