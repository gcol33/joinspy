# Joins in Production

At the console, we see the wrong row count, fix the key, and re-run. In
a scheduled script, the same issue goes unnoticed until someone looks at
the output. This vignette wires joinspy into automated pipelines so that
join problems surface as errors or log entries. Every example uses
synthetic data and [`tempfile()`](https://rdrr.io/r/base/tempfile.html)
paths, so the whole thing runs end to end.

## Assertions with key_check()

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
returns a single logical – `TRUE` if no issues were detected, `FALSE`
otherwise. The simplest assertion wraps it in
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

With `warn = FALSE`, the printed diagnostics are suppressed – in a cron
job or CI pipeline, we want the script to fail hard rather than print
warnings. An explicit `if`/`stop` gives us a custom error message:

``` r

if (!key_check(orders_dirty, customers, by = "customer_id", warn = FALSE)) {
  stop("Key quality check failed for orders-customers join. ",
       "Run join_spy() interactively for details.", call. = FALSE)
}
#> Error:
#> ! Key quality check failed for orders-customers join. Run join_spy() interactively for details.
```

We can also chain the assertion with a repair step – run
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
first, repair on failure, then re-check:

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

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
is a binary pass/fail gate;
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
builds a full report with match rates, expected row counts, and
categorized issues. In production,
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
runs on every execution.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
is what we reach for when an assertion fails and we need to understand
why.

## Silent Joins in Pipelines

The `*_join_spy()` wrappers print diagnostic output by default. In a
scheduled script, `.quiet = TRUE` suppresses all printed output while
still computing the report internally.

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

The report is still available via
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md):

``` r

rpt <- last_report()
rpt$match_analysis$match_rate
#> [1] 0.75
```

The join runs silently; later, we pull the report and check its contents
programmatically:

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

The report object is a plain list, so standard R subsetting works for
arbitrarily complex validation logic.

One caveat:
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
stores only the most recent report. If a script performs three joins in
sequence, only the third report survives. To retain earlier reports,
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
enforces a cardinality constraint and throws an error if it is violated.

In development, we use
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

One-to-many: each product appears once in `products` but can appear
multiple times in `line_items`. We encode that expectation in
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

If someone loads a `products` table with duplicate product IDs, the
script fails immediately:

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

The four cardinality levels:

- **1:1** – lookup to lookup. Each key appears exactly once on both
  sides.

- **1:m** – reference on the left, transactions on the right (products
  to line items, stations to hourly readings).

- **m:1** – transactions on the left, lookup on the right (sales joined
  to a region table).

- **m:m** – duplicates on both sides. Almost always a bug; requiring an
  explicit `expect = "m:m"` acts as a speed bump.

In practice, `"1:m"` and `"m:1"` cover most production joins.
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
confirms the relationship during development; the `expect` value is then
hard-coded in the production script.

[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
solves a different problem: it warns about Cartesian product explosion
when a key has many duplicates on *both* sides. A join can violate a
`"1:1"` constraint without triggering a Cartesian explosion (one extra
duplicate is enough), and a `"m:m"` join can produce a massive product
that
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
would allow. The two functions complement each other.

## Logging and Audit Trails

### Manual logging

[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
writes a single report to a file. The format depends on the file
extension:

``` r

report <- join_spy(sensors, readings, by = "sensor_id")

# Text format -- human-readable
txt_log <- tempfile(fileext = ".log")
log_report(report, txt_log)
#> ✔ Report logged to C:/Temp\Rtmp2BnYNR\file31bf43ca12605.log
cat(readLines(txt_log), sep = "\n")
#> Logged: 2026-03-31 23:21:09
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
#> ✔ Report logged to C:/Temp\Rtmp2BnYNR\file31bf41787369d.json
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
#>   "logged_at": "2026-03-31 23:21:09"
#> }
unlink(json_log)
```

Text format works for tailing logs during a batch run; JSON format feeds
into monitoring systems or downstream scripts. Reports can also be saved
as `.rds` files, which preserves the full R object for later interactive
inspection.

### Automatic logging

For scripts with many joins,
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
at the top is cleaner than calling
[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
after each one. Every subsequent `*_join_spy()` call appends its report
to the file.

``` r

auto_log <- tempfile(fileext = ".log")
set_log_file(auto_log, format = "text")
#> ℹ Automatic logging enabled: C:/Temp\Rtmp2BnYNR\file31bf429b81d46.log

# These joins are automatically logged
result1 <- left_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)
result2 <- inner_join_spy(sensors, readings, by = "sensor_id", .quiet = TRUE)

# Check what got logged
cat(readLines(auto_log), sep = "\n")
#> 
#> Logged: 2026-03-31 23:21:09
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
#> Logged: 2026-03-31 23:21:09
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

Automatic logging only triggers from `*_join_spy()` wrappers.
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
and bare [`merge()`](https://rdrr.io/r/base/merge.html) calls are not
logged – the wrappers are the instrumented path. To combine cardinality
enforcement with logging, run
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
as a separate check and use a `*_join_spy()` wrapper for the actual
join.

[`get_log_file()`](https://gillescolling.com/joinspy/reference/get_log_file.md)
returns the current log path (or `NULL` if logging is disabled):

``` r

# Only log if logging is configured
if (!is.null(get_log_file())) {
  message("Logging is active at: ", get_log_file())
}
```

## Sampling for Large Datasets

The `sample` parameter in
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
runs the analysis on a random subset while the actual join (via a
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
#>    0.11    0.06    0.18

# Sampled analysis
system.time(report_sampled <- join_spy(big_orders, big_customers,
                                        by = "customer_id", sample = 5000))
#>    user  system elapsed 
#>    0.09    0.00    0.09
```

The sampled report is approximate – match rates and duplicate counts are
estimated from the subset. For production monitoring, we typically care
whether the match rate is roughly 95% or roughly 60%, not whether it is
94.7% or 95.1%. Sampling catches systemic problems (wrong key column,
widespread encoding issues, duplicate explosion) with a fraction of the
runtime.

Sampling can miss rare issues. If 0.1% of keys have a zero-width space,
a 5,000-row sample from a 10-million-row table might not include any.
Running full diagnostics periodically (weekly, or when the upstream
source changes) alongside sampled daily runs covers both speed and
thoroughness.

## A Complete Production Pattern

Here is a realistic production workflow: a nightly job loads order and
customer data, validates keys, repairs if needed, joins with cardinality
enforcement, and logs everything.

``` r

# ============================================================
# Nightly order enrichment pipeline
# ============================================================

# --- Setup logging ---
pipeline_log <- tempfile(fileext = ".log")
set_log_file(pipeline_log, format = "text")
#> ℹ Automatic logging enabled: C:/Temp\Rtmp2BnYNR\file31bf4120083b.log

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
#> Logged: 2026-03-31 23:21:10
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

The three gates catch different failure modes:
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
catches string-level problems and attempts repair,
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
halts on unexpected many-to-many relationships, and the row count check
guards against anything the first two gates missed. Logging runs
throughout because
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
was called at the top. The structure scales – more tables, more gates,
more joins, same pattern.
