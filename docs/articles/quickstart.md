# Quick Start

joinspy diagnoses join keys before you join. It surfaces the
string-level problems that kill match rates (whitespace, case, encoding,
typos) and offers one-call repair. Works with base R, dplyr, and
data.table.

## String Diagnostics

The keys *look* identical but differ at the byte level: a trailing
space, a case mismatch, an invisible Unicode character. These
differences don’t show up in [`str()`](https://rdrr.io/r/utils/str.html)
or [`summary()`](https://rdrr.io/r/base/summary.html) output, but they
determine whether a join matches.

### Whitespace

Trailing and leading whitespace is the most common reason keys fail to
match. A column exported from Excel might contain `"London "` alongside
`"London"`, and R treats those as distinct values.

``` r

sales <- data.frame(
  city = c("London", "Paris ", " Berlin", "Tokyo"),
  revenue = c(500, 300, 450, 600),
  stringsAsFactors = FALSE
)

cities <- data.frame(
  city = c("London", "Paris", "Berlin", "Tokyo", "Madrid"),
  country = c("UK", "France", "Germany", "Japan", "Spain"),
  stringsAsFactors = FALSE
)

report <- join_spy(sales, cities, by = "city")
```

The report flags the whitespace problems and shows which values are
affected. `"Paris "` and `" Berlin"` both fail to match, dropping the
match rate from 100% to 50%.

Whitespace problems compound with multi-column keys:

``` r

sales2 <- data.frame(
  city = c("London", "Paris ", "Berlin"),
  district = c("West ", "Central", " Mitte"),
  revenue = c(500, 300, 450),
  stringsAsFactors = FALSE
)

districts <- data.frame(
  city = c("London", "Paris", "Berlin"),
  district = c("West", "Central", "Mitte"),
  pop = c(200000, 350000, 180000),
  stringsAsFactors = FALSE
)

report <- join_spy(sales2, districts, by = c("city", "district"))
```

London fails on the district column, Paris on the city column. A row
needs all key columns to match, so a single trailing space in any column
breaks the join.

For a quick pass/fail gate, we can use
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md):

``` r

key_check(sales, cities, by = "city")
#> ! Key check found 1 issue(s):
#> ✖ Left table column 'city' has whitespace issues (2 values)
```

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
returns `FALSE` here because of the whitespace, and with `warn = TRUE`
(the default) it prints which issues it found. It returns a single
logical, so it slots into
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) or conditional
logic.

### Case Mismatches

A CRM might store `"ACME"` while the billing system stores `"Acme"`, and
R treats these as distinct strings.

``` r

invoices <- data.frame(
  company = c("ACME", "globex", "Initech", "UMBRELLA"),
  amount = c(1200, 800, 950, 1500),
  stringsAsFactors = FALSE
)

vendors <- data.frame(
  company = c("Acme", "Globex", "Initech", "Umbrella"),
  sector = c("Manufacturing", "Logistics", "Software", "Biotech"),
  stringsAsFactors = FALSE
)

report <- join_spy(invoices, vendors, by = "company")
```

Only `"Initech"` matches exactly; the other three would be lost in a
standard join. The `match_analysis` section shows the potential match
rate both with and without case sensitivity.

### Encoding and Invisible Characters

Two strings can render identically in the console but differ at the byte
level: a non-breaking space (`\u00A0`) versus a regular space, a
zero-width space from PDF copy-paste.

``` r

# Simulate invisible character contamination
raw_ids <- data.frame(
  product_id = c("SKU-001", "SKU-002", paste0("SKU-003", "\u200B")),
  batch = c("A", "B", "C"),
  stringsAsFactors = FALSE
)

clean_ids <- data.frame(
  product_id = c("SKU-001", "SKU-002", "SKU-003"),
  warehouse = c("East", "West", "North"),
  stringsAsFactors = FALSE
)

report <- join_spy(raw_ids, clean_ids, by = "product_id")
```

The zero-width space appended to `"SKU-003"` is invisible when printed
but prevents the match. joinspy flags this under encoding issues and
identifies the specific Unicode code points involved.

### Combining Multiple Issues

Real data rarely has just one problem.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
checks for whitespace, case, and encoding issues in one call and reports
them together, grouped by type.

``` r

employees <- data.frame(
  dept = c("Sales ", "ENGINEERING", "marketing", paste0("HR", "\u00A0")),
  name = c("Alice", "Bob", "Carol", "David"),
  stringsAsFactors = FALSE
)

departments <- data.frame(
  dept = c("Sales", "Engineering", "Marketing", "HR"),
  budget = c(50000, 80000, 45000, 30000),
  stringsAsFactors = FALSE
)

report <- join_spy(employees, departments, by = "dept")
```

Zero matches out of four rows, with the problems grouped by type. The
fix differs per category: whitespace is safe to trim automatically, case
standardization requires choosing a direction, and encoding issues may
indicate deeper pipeline problems.

### Duplicate Keys

Duplicates don’t prevent matches, but they multiply rows. If `"London"`
appears three times in the left table and twice in the right, we get six
rows for London after an inner join.

[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)
returns the offending rows along with a count:

``` r

transactions <- data.frame(
  store_id = c("S1", "S1", "S2", "S3", "S3", "S3"),
  day = c("Mon", "Tue", "Mon", "Mon", "Tue", "Wed"),
  amount = c(100, 200, 150, 300, 250, 400),
  stringsAsFactors = FALSE
)

key_duplicates(transactions, by = "store_id")
#>   store_id day amount .n_duplicates
#> 1       S1 Mon    100             2
#> 2       S1 Tue    200             2
#> 4       S3 Mon    300             3
#> 5       S3 Tue    250             3
#> 6       S3 Wed    400             3
```

The `keep` argument accepts `"first"`, `"last"`, or the default `"all"`.
The `.n_duplicates` column maps directly to the row multiplication
factor in a join.

## Auto-Repair

[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
handles whitespace trimming, case standardization, invisible character
removal, and empty-to-NA conversion in a single call.

### Dry Run

We can preview what
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
would change with `dry_run = TRUE`:

``` r

messy_left <- data.frame(
  id = c(" A-101", "B-202 ", "c-303", paste0("D-404", "\u200B")),
  score = c(88, 92, 76, 95),
  stringsAsFactors = FALSE
)

messy_right <- data.frame(
  id = c("A-101", "B-202", "C-303", "D-404"),
  label = c("Alpha", "Beta", "Gamma", "Delta"),
  stringsAsFactors = FALSE
)

join_repair(messy_left, messy_right, by = "id", dry_run = TRUE)
#> 
#> ── Repair Preview (Dry Run) ────────────────────────────────────────────────────
#> 
#> ── Left table (x) ──
#> 
#> ℹ id: trimmed whitespace (2), removed invisible chars (1)
```

The dry run shows how many values will change and what they become,
without touching the original data.

### Applying Repairs

Drop `dry_run` (or set it to `FALSE`) to get back the repaired data
frames. When we pass both `x` and `y`, the return value is a list with
both:

``` r

repaired <- join_repair(
  messy_left, messy_right,
  by = "id",
  trim_whitespace = TRUE,
  standardize_case = "upper",
  remove_invisible = TRUE
)
#> ✔ Repaired 4 value(s)

repaired$x$id
#> [1] "A-101" "B-202" "C-303" "D-404"
repaired$y$id
#> [1] "A-101" "B-202" "C-303" "D-404"
```

Both sides now have clean, uppercase, whitespace-free keys. We can
confirm with
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md):

``` r

key_check(repaired$x, repaired$y, by = "id")
#> ✔ Key check passed: no issues detected
```

[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
fixes mechanical string problems: whitespace, case, invisible
characters, empty strings. It does not fix typos, semantic mismatches,
or different key formats (`"USA"` vs. `"United States"`).

### Repair Suggestions from a Report

If we already have a `JoinReport` from
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
generates ready-to-run code that fixes the detected issues:

``` r

report <- join_spy(messy_left, messy_right, by = "id")
suggest_repairs(report)
#> 
#> ── Suggested Repairs ───────────────────────────────────────────────────────────
#> x$id <- trimws(x$id)
#> # Remove invisible characters:
#> x$id <- gsub("[\u200B\u200C\u200D\uFEFF\u00A0]", "", x$id, perl = TRUE)
#> # Standardize case:
#> x$id <- tolower(x$id)
#> y$id <- tolower(y$id)
```

The generated code calls
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
with the appropriate flags based on what the report detected.

## Row Count Predictions

Every `JoinReport` includes an `expected_rows` component that predicts
how many rows each join type will produce, calculated from key overlap
and duplicate structure.

``` r

orders <- data.frame(
  product_id = c("P1", "P1", "P2", "P3", "P4"),
  quantity = c(10, 5, 20, 15, 8),
  stringsAsFactors = FALSE
)

products <- data.frame(
  product_id = c("P1", "P2", "P3", "P5"),
  name = c("Widget", "Gadget", "Gizmo", "Doohickey"),
  stringsAsFactors = FALSE
)

report <- join_spy(orders, products, by = "product_id")
report$expected_rows
#> $inner
#> [1] 4
#> 
#> $left
#> [1] 5
#> 
#> $right
#> [1] 5
#> 
#> $full
#> [1] 6
```

A left join here retains all five order rows (with `NA` for the
unmatched `"P4"`), while an inner join drops it.

For each join type, the calculation counts overlapping keys and
multiplies by the number of duplicates on each side. A key appearing
twice in `x` and three times in `y` contributes 2 \* 3 = 6 rows to an
inner join. The calculation is exact when all keys are non-NA and no
string issues remain. NA keys deserve caution: R’s
[`merge()`](https://rdrr.io/r/base/merge.html) and dplyr both skip NAs
by default, so the predicted count may overestimate. The report warns
when NAs are present.

[`summary()`](https://rdrr.io/r/base/summary.html) returns the same
information as a compact data frame:

``` r

summary(report)
#>               metric value
#> 1          left_rows  5.00
#> 2         right_rows  4.00
#> 3   left_unique_keys  4.00
#> 4  right_unique_keys  4.00
#> 5       keys_matched  3.00
#> 6     keys_left_only  1.00
#> 7    keys_right_only  1.00
#> 8         match_rate  0.75
#> 9             issues  1.00
#> 10   inner_join_rows  4.00
#> 11    left_join_rows  5.00
#> 12   right_join_rows  5.00
#> 13    full_join_rows  6.00
```

## Post-Join Diagnostics

Sometimes the join has already happened and we need to understand the
result.

### Explaining Row Count Changes

[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
takes the result, the two input tables, and the join column, then
explains why the row count changed:

``` r

tickets <- data.frame(
  event_id = c(1, 2, 2, 3),
  seat = c("A1", "B2", "B3", "C1"),
  stringsAsFactors = FALSE
)

events <- data.frame(
  event_id = c(1, 2, 4),
  name = c("Concert", "Play", "Opera"),
  stringsAsFactors = FALSE
)

result <- merge(tickets, events, by = "event_id")
join_explain(result, tickets, events, by = "event_id", type = "inner")
#> 
#> ── Join Explanation ────────────────────────────────────────────────────────────
#> 
#> ── Row Counts ──
#> 
#> Left table (x): 4 rows
#> Right table (y): 3 rows
#> Result: 3 rows
#> ℹ Result has 1 fewer rows than left table
#> 
#> ── Why the row count changed ──
#> 
#> ℹ Left table has 1 duplicate key(s) - each match creates multiple rows
#> ℹ Inner join dropped 1 unmatched left rows
```

The output decomposes the row count into contributions from matched
keys, unmatched keys, and duplicate-driven expansion. Usually when a
table grows unexpectedly, the answer is a handful of keys with
duplicates on one side.

### Before/After Comparison

[`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md)
compares a data frame before and after a join to show which rows were
added, dropped, or preserved:

``` r

before <- data.frame(
  id = 1:4,
  value = c("a", "b", "c", "d"),
  stringsAsFactors = FALSE
)

lookup <- data.frame(
  id = c(2, 3, 4, 5),
  extra = c("X", "Y", "Z", "W"),
  stringsAsFactors = FALSE
)

after <- merge(before, lookup, by = "id", all = TRUE)
join_diff(before, after, by = "id")
#> 
#> ── Join Diff ───────────────────────────────────────────────────────────────────
#> 
#> ── Dimensions ──
#> 
#> Before: 4 rows x 2 columns
#> After: 5 rows x 3 columns
#> Change: "+1" rows, "+1" columns
#> 
#> ── Column Changes ──
#> 
#> ✔ Added: extra
#> 
#> ── Key Analysis ──
#> 
#> Unique keys before: 4
#> Unique keys after: 5
```

Row 1 was dropped (no match in the right table for a non-full join is
irrelevant here since we used `all = TRUE`; but row 5 was added from the
right table).

Here is a second example that highlights row addition from duplicates
rather than new keys:

``` r

before2 <- data.frame(
  id = c(1, 2, 3),
  value = c("a", "b", "c"),
  stringsAsFactors = FALSE
)

dup_lookup <- data.frame(
  id = c(1, 1, 2, 3),
  tag = c("X", "Y", "Z", "W"),
  stringsAsFactors = FALSE
)

after2 <- merge(before2, dup_lookup, by = "id")
join_diff(before2, after2, by = "id")
#> 
#> ── Join Diff ───────────────────────────────────────────────────────────────────
#> 
#> ── Dimensions ──
#> 
#> Before: 3 rows x 2 columns
#> After: 4 rows x 3 columns
#> Change: "+1" rows, "+1" columns
#> 
#> ── Column Changes ──
#> 
#> ✔ Added: tag
#> 
#> ── Key Analysis ──
#> 
#> Unique keys before: 3
#> Unique keys after: 3
#> Duplicate rows: "+2"
```

The row count grew from three to four because `id = 1` matched two rows
in the lookup. No new keys were introduced; the growth came entirely
from duplicate expansion.
[`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md)
distinguishes these two sources of row addition (new keys vs. duplicate
expansion).

## Safe Join Wrappers

The `*_join_spy()` family wraps standard joins with automatic
diagnostics. They print a report before joining and return the joined
data frame:

``` r

patients <- data.frame(
  patient_id = c("P01", "P02", "P03"),
  age = c(34, 28, 45),
  stringsAsFactors = FALSE
)

labs <- data.frame(
  patient_id = c("P01", "P02", "P04"),
  result = c(5.2, 3.8, 6.1),
  stringsAsFactors = FALSE
)

result <- left_join_spy(patients, labs, by = "patient_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: patient_id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 1
#> Keys only in right: 1
#> Match rate (left): "66.7%"
#> 
#> ── Issues Detected ──
#> 
#> ℹ 3 near-match(es) found (e.g., 'P03' ~ 'P01', 'P03' ~ 'P02', 'P03' ~ 'P04') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 3
#> right_join: 3
#> full_join: 4
#> ℹ Performing "left" join...
#> ✔ Result: 3 rows (as expected)
head(result)
#>   patient_id age result
#> 1        P01  34    5.2
#> 2        P02  28    3.8
#> 3        P03  45     NA
```

All four wrappers (`left_join_spy`, `right_join_spy`, `inner_join_spy`,
`full_join_spy`) share the same interface. The wrappers are convenient
for exploratory work; in production, we might prefer calling
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
first and inspecting the report programmatically before proceeding. The
wrappers also accept a `backend` parameter (`"base"`, `"dplyr"`, or
`"data.table"`) that overrides automatic backend detection.

### Quiet Mode and Deferred Reports

In pipelines, printed output can be distracting. With `.quiet = TRUE`,
the report is suppressed and can be retrieved afterward via
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md):

``` r

result <- inner_join_spy(patients, labs, by = "patient_id", .quiet = TRUE)

# Later, inspect what happened
rpt <- last_report()
rpt$match_analysis$match_rate
#> [1] 0.6666667
```

[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
returns the report from the most recent `*_join_spy()` call and persists
for the duration of the R session.

## Cardinality Enforcement

[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
performs a join that errors if the key relationship violates a stated
expectation. This is a guard against unexpected many-to-many joins that
multiply rows.

``` r

sensors <- data.frame(
  sensor_id = c("T1", "T2", "T3"),
  location = c("Roof", "Basement", "Lobby"),
  stringsAsFactors = FALSE
)

readings <- data.frame(
  sensor_id = c("T1", "T2", "T3"),
  value = c(22.1, 18.5, 21.0),
  stringsAsFactors = FALSE
)

# Succeeds: one reading per sensor
join_strict(sensors, readings, by = "sensor_id", expect = "1:1")
#>   sensor_id location value
#> 1        T1     Roof  22.1
#> 2        T2 Basement  18.5
#> 3        T3    Lobby  21.0
```

``` r

# Fails: T1 has two readings, violating 1:1
readings_dup <- data.frame(
  sensor_id = c("T1", "T1", "T2", "T3"),
  value = c(22.1, 23.4, 18.5, 21.0),
  stringsAsFactors = FALSE
)

join_strict(sensors, readings_dup, by = "sensor_id", expect = "1:1")
#> Error:
#> ! Cardinality violation: expected 1:1 but found 1:m
#>   Left duplicates: 0, Right duplicates: 1
```

The `expect` argument accepts four cardinality levels:

- `"1:1"`: both sides have unique keys. Any duplicate on either side is
  an error.

- `"1:m"`: the left table has unique keys, the right may repeat. The
  classic lookup-table join.

- `"m:1"`: the mirror of `"1:m"`. The right table is the lookup.

- `"m:m"`: duplicates allowed on both sides. Rarely what we want; exists
  as an explicit opt-in for intentional Cartesian products per key.

To detect the actual cardinality without enforcing anything:

``` r

detect_cardinality(sensors, readings_dup, by = "sensor_id")
#> ℹ Detected cardinality: "1:m"
#> Right duplicates: 1 key(s)
```

This returns a string like `"1:m"` that we can use programmatically,
e.g. to select the right `expect` value or to log the cardinality for
monitoring.

## Advanced Features

### Cartesian Product Detection

When both tables have duplicates on the same key, the join produces the
Cartesian product of those duplicates. Two keys with 100 rows each
produce 10,000 rows for that key alone.
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
warns before this happens:

``` r

left <- data.frame(
  group = c("A", "A", "A", "B"),
  x = 1:4,
  stringsAsFactors = FALSE
)

right <- data.frame(
  group = c("A", "A", "B", "B"),
  y = 5:8,
  stringsAsFactors = FALSE
)

check_cartesian(left, right, by = "group")
#> ✔ No Cartesian product risk (expansion factor: 2x)
```

The `threshold` argument (default 10) controls how large the expansion
factor must be before a warning fires.

### Multi-Table Join Chains

[`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md)
runs diagnostics across a sequence of joins. We provide a named list of
tables and a list of join specifications:

``` r

orders <- data.frame(
  order_id = 1:4,
  customer_id = c(1, 2, 2, 3),
  stringsAsFactors = FALSE
)

customers <- data.frame(
  customer_id = 1:3,
  region_id = c(1, 1, 2),
  stringsAsFactors = FALSE
)

regions <- data.frame(
  region_id = 1:2,
  name = c("North", "South"),
  stringsAsFactors = FALSE
)

analyze_join_chain(
  tables = list(orders = orders, customers = customers, regions = regions),
  joins = list(
    list(left = "orders", right = "customers", by = "customer_id"),
    list(left = "result", right = "regions", by = "region_id")
  )
)
#> 
#> ── Join Chain Analysis ─────────────────────────────────────────────────────────
#> 
#> ── Step 1: orders + customers ──
#> 
#> Left: 4 rows
#> Right: 3 rows
#> Match rate: 100%
#> Expected result: 4 rows (left join)
#> ! 1 issue(s) detected
#> 
#> ── Step 2: result + regions ──
#> 
#> Left: 4 rows
#> Right: 2 rows
#> Match rate: 100%
#> Expected result: 4 rows (left join)
#> ! 1 issue(s) detected
#> 
#> ── Chain Summary ──
#> 
#> ! Total issues across chain: 2
```

Each step prints a diagnostic report. The special name `"result"` refers
to the output of the previous join, so we can chain as many tables as
needed. Because `"result"` resolves to the actual intermediate data, key
diagnostics at step two account for any NAs or key distribution changes
introduced by the first join.

### Backend Support

All join wrappers and
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
accept a `backend` argument. By default (`backend = NULL`), joinspy
detects the backend from the input class: tibbles use dplyr, data.tables
use data.table, plain data frames use base R.

``` r

# Force dplyr backend even for plain data frames
left_join_spy(x, y, by = "id", backend = "dplyr")

# Force base R for tibbles
left_join_spy(x, y, by = "id", backend = "base")
```

The diagnostic layer is backend-agnostic; all string analysis and key
checking happens before the join engine is invoked, so reports are
identical regardless of backend.

## Quick Reference

| Function | Purpose | Returns |
|----|----|----|
| [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) | Full pre-join diagnostic | `JoinReport` (print/summary/plot) |
| [`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md) | Quick pass/fail | Logical |
| [`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md) | Find duplicate keys | Data frame with `.n_duplicates` |
| [`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md) | Fix whitespace, case, encoding | Repaired data frame(s) |
| [`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md) | Print repair code snippets | Printed output (invisible) |
| [`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md) | Left join + diagnostics | Joined data frame |
| [`right_join_spy()`](https://gillescolling.com/joinspy/reference/right_join_spy.md) | Right join + diagnostics | Joined data frame |
| [`inner_join_spy()`](https://gillescolling.com/joinspy/reference/inner_join_spy.md) | Inner join + diagnostics | Joined data frame |
| [`full_join_spy()`](https://gillescolling.com/joinspy/reference/full_join_spy.md) | Full join + diagnostics | Joined data frame |
| [`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md) | Retrieve last quiet report | `JoinReport` or `NULL` |
| [`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md) | Cardinality-enforcing join | Joined data frame or error |
| [`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md) | Explain row count change | Printed summary |
| [`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md) | Before/after comparison | Printed summary |
| [`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md) | Detect key relationship | Character (`"1:1"`, etc.) |
| [`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md) | Warn about row explosion | List with explosion analysis |
| [`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md) | Multi-step join diagnostics | Printed chain analysis |
| [`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md) | Write report to file | File output (invisible) |
| [`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md) | Enable auto-logging | Sets global log path |

## Further Reading

- [`vignette("common-issues")`](https://gillescolling.com/joinspy/articles/common-issues.md)
  for a catalogue of join problems and solutions

- Function help pages:
  [`?join_spy`](https://gillescolling.com/joinspy/reference/join_spy.md),
  [`?join_repair`](https://gillescolling.com/joinspy/reference/join_repair.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)
