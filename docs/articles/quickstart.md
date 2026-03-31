# Quick Start

joinspy diagnoses join keys before you join. It surfaces the
string-level problems that kill match rates (whitespace, case, encoding,
typos) and offers one-call repair. Works with base R, dplyr, and
data.table.

## String Diagnostics

Most failed joins are not caused by missing data. They fail because the
keys *look* identical but are not: a trailing space, a case mismatch, an
invisible Unicode character. These problems are hard to spot by eye and
rarely show up in [`str()`](https://rdrr.io/r/utils/str.html) or
[`summary()`](https://rdrr.io/r/base/summary.html). joinspy was built to
catch them.

### Whitespace

Trailing and leading whitespace is the single most common reason keys
fail to match. A column exported from Excel or read from a CSV will
often contain `"London "` alongside `"London"`, and R sees those as two
distinct values.

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

Once printed, the report flags the whitespace problems and tells you
exactly which values are affected. The `match_analysis` section shows
what the match rate would be if those issues were fixed; here,
`"Paris "` and `" Berlin"` both fail to match their clean counterparts,
dropping the match rate from 100% to 50%.

Whitespace problems compound when keys span multiple columns. Suppose
you join on both city and district:

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

Now London fails on the district column and Paris fails on the city
column. Each column is checked independently; a row needs all key
columns to match, so a single trailing space in any one of them is
enough to break the join.

For a quick pass/fail gate in scripts, use
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md):

``` r

key_check(sales, cities, by = "city")
#> ! Key check found 1 issue(s):
#> ✖ Left table column 'city' has whitespace issues (2 values)
```

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
returns `FALSE` here because of the whitespace. When `warn = TRUE` (the
default), it also prints which issues it found. This makes
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
useful as an assertion in automated pipelines: wrap it in
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) and the script
halts before a broken join silently drops rows. Unlike
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
which returns a full report object,
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
is deliberately minimal (a single logical value) so it slots cleanly
into conditional logic.

### Case Mismatches

Databases and spreadsheets handle case differently. A CRM might store
`"ACME"` while the billing system stores `"Acme"`, and R treats these as
distinct strings.

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

Each case-mismatched pair is listed in the output. Only `"Initech"`
matches exactly; the other three would be lost in a standard join. Case
conflicts are particularly common when merging data from systems with
different conventions: CRMs that uppercase everything, ERPs that
title-case, web forms that accept freeform input. The `match_analysis`
section of the report shows the potential match rate both with and
without case sensitivity, so you can gauge whether standardizing case
would recover most of the lost matches.

### Encoding and Invisible Characters

Encoding issues are the nastiest. Nothing visible to debug. Two strings
render identically in the console but differ at the byte level: a
non-breaking space (`\u00A0`) versus a regular space, a Latin-1 accented
character versus its UTF-8 equivalent.

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
but prevents the join from matching. joinspy flags this under encoding
issues. Other common culprits include non-breaking spaces (`\u00A0`),
byte-order marks, and right-to-left marks that creep in from PDF
copy-paste or web scraping. Standard R string functions
([`trimws()`](https://rdrr.io/r/base/trimws.html),
[`nchar()`](https://rdrr.io/r/base/nchar.html)) will not catch these
because they operate on visible characters only. By identifying the
specific Unicode code points involved, joinspy saves considerable
debugging time compared to staring at two strings that look identical in
the console.

### Combining Multiple Issues

Real data rarely has just one problem. A single key column might have
trailing whitespace on some rows, case mismatches on others, invisible
characters on a third set.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
checks for all of these in one call and reports them together, grouped
by type.

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

Zero matches out of four rows. Grouped by problem type (whitespace,
case, encoding), the output lets you decide how to address each one.
This matters because the fix differs: whitespace is safe to trim
automatically, case standardization requires choosing a direction
(upper, lower, or title), and encoding issues sometimes indicate deeper
data pipeline problems that trimming alone will not solve. The grouped
output lets you prioritize; often fixing whitespace and case recovers
90% of lost matches, and the remaining encoding problems can be handled
case by case.

### Duplicate Keys

Duplicates do not prevent matches, but they multiply rows. If `"London"`
appears three times in the left table and twice in the right, you get
six rows for London after an inner join, often unintentionally.

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

Use `keep = "first"` or `keep = "last"` to return only the first or last
occurrence per key. The default `keep = "all"` returns every row that
participates in a duplicate group. The `.n_duplicates` column in the
output tells you the group size, which directly maps to the row
multiplication factor: a key with `.n_duplicates = 3` in the left table
and `.n_duplicates = 2` in the right will produce 6 rows for that key in
an inner join.

## Auto-Repair

Once you know what is wrong, joinspy can fix it.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
handles whitespace trimming, case standardization, invisible character
removal, and empty-to-NA conversion in a single call.

### Dry Run

Always preview repairs before applying them. The `dry_run = TRUE` option
shows what would change without modifying the data:

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

The dry run tells you how many values will change and in which
direction, without touching the original data frames. Review this output
carefully: it shows which values will be modified and what they will
become. Review carefully for case standardization, where uppercasing a
key like `"c-303"` to `"C-303"` is correct, but you want to verify that
both tables agree on the target format before committing.

### Applying Repairs

Drop `dry_run` (or set it to `FALSE`) to get back the repaired data
frames. When you pass both `x` and `y`, the return value is a list with
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

Both sides now have clean, uppercase, whitespace-free keys. You can pass
the repaired tables straight into a join.

To confirm the repairs worked, run
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
on the repaired tables:

``` r

key_check(repaired$x, repaired$y, by = "id")
#> ✔ Key check passed: no issues detected
```

This should return `TRUE` with no warnings. Running
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
after repair is good practice because it catches edge cases where
trimming or case standardization was not enough (for instance, if two
distinct keys collapse into the same value after uppercasing).

One important caveat:
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
fixes mechanical string problems: whitespace, case, invisible
characters, empty strings. It does not fix typos, semantic mismatches,
or fundamentally different key formats. If one table uses `"USA"` and
the other uses `"United States"`, or one stores product codes as
`"P-001"` while the other uses `"001"`, repair will not bridge that gap.
Those require manual recoding or a lookup table.

### Repair Suggestions from a Report

If you already have a `JoinReport` from
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
call
[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
to get ready-to-run R code that fixes the detected issues:

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

This prints code snippets you can copy into your script. It is
deliberately not automatic: you should review the suggestions before
running them. The generated code calls
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
with the appropriate flags enabled based on what the report detected, so
you do not have to remember which issues were present.

## Row Count Predictions

Every `JoinReport` includes an `expected_rows` component that predicts
how many rows each join type will produce, calculated from the key
overlap and duplicate structure, before any join is executed.

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

The predictions help you anticipate whether a join will shrink, grow, or
explode your data. A left join here should retain all five order rows
(with `NA` for the unmatched `"P4"`), while an inner join drops it.

How does joinspy compute these numbers? For each join type, it counts
the overlapping keys between the two tables and multiplies by the number
of duplicates on each side. A key that appears twice in `x` and three
times in `y` contributes 2 \* 3 = 6 rows to an inner join. Non-matching
keys add rows for left, right, and full joins according to the usual
rules. The calculation is exact when all keys are non-NA and no string
issues remain; however, NA keys deserve caution. R’s
[`merge()`](https://rdrr.io/r/base/merge.html) does not match NAs by
default (and neither does dplyr), so if either table contains NA keys,
the predicted row count may overestimate the actual result. The report
warns you when NAs are present in the key columns so you can account for
this.

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

Sometimes the join has already happened and you need to understand the
result.

### Explaining Row Count Changes

[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
takes the result, the two input tables, and the join column, then tells
you why the row count changed:

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

The output breaks down the row count into contributions from matched
keys, unmatched keys, and duplicate-driven expansion. Specifically, you
get: the number of keys that matched in both tables; how many rows each
matched key contributed (accounting for duplicates); which keys from
each table had no match; and the net effect on row count compared to the
left table. This decomposition makes it straightforward to answer
questions like “why did my table grow by 200 rows?”, and usually the
answer is a handful of keys with unexpected duplicates on one side. If
you omit `type`, joinspy infers the join type from the row counts
(though providing it explicitly is more reliable).

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
right table). This kind of accounting is tedious to do by hand on large
data.

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

Here the row count grew from three to four because `id = 1` matched two
rows in the lookup. No new keys were introduced; the growth came
entirely from duplicate-driven expansion.
[`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md)
distinguishes these two sources of row addition (new keys vs. duplicate
expansion), which is the key information you need when debugging an
unexpectedly large result.

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
`full_join_spy`) share the same interface.

When should you use a wrapper instead of calling
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
manually? The wrappers are convenient for exploratory work and
interactive sessions where you want diagnostics printed as a side effect
without breaking your pipeline. In production scripts, you may prefer
calling
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
first, inspecting the report programmatically (checking `report$issues`
or `report$expected_rows`), and only proceeding with the join if the
diagnostics pass. The wrappers also accept a `backend` parameter
(`"base"`, `"dplyr"`, or `"data.table"`) that overrides the automatic
backend detection; this is useful when you want to force a specific join
engine regardless of the input class.

### Quiet Mode and Deferred Reports

In pipelines, printed output is distracting. Use `.quiet = TRUE` to
suppress the report, then retrieve it afterward with
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md):

``` r

result <- inner_join_spy(patients, labs, by = "patient_id", .quiet = TRUE)

# Later, inspect what happened
rpt <- last_report()
rpt$match_analysis$match_rate
#> [1] 0.6666667
```

[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
always returns the report from the most recent `*_join_spy()` call,
regardless of which wrapper was used. The report object is stored in an
internal environment and persists for the duration of the R session, so
you can inspect it at any point after the join – even after several more
lines of pipeline code have executed.

## Cardinality Enforcement

[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
performs a join that throws an error if the key relationship violates
your expectation. This is useful as a guard in production scripts where
a surprise many-to-many relationship would corrupt downstream results.

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

The `expect` argument accepts four cardinality levels, each appropriate
for different scenarios:

- `"1:1"`: both sides have unique keys. Use this when merging two
  reference tables (e.g., a country table with a currency table, both
  keyed on country code). Any duplicate on either side is an error.
- `"1:m"`: the left table has unique keys, the right may repeat. This is
  the classic lookup-table join: a product catalogue (left) joined to a
  transactions table (right) where each product appears in many
  transactions.
- `"m:1"`: the mirror of `"1:m"`. The right table is the lookup; the
  left table has repeats.
- `"m:m"`: duplicates are allowed on both sides. This disables the
  constraint entirely and is rarely what you want; it exists as an
  explicit opt-in for the rare cases where a Cartesian product per key
  is intentional (e.g., generating all pairings between two sets of
  attributes).

To detect the actual cardinality without enforcing anything:

``` r

detect_cardinality(sensors, readings_dup, by = "sensor_id")
#> ℹ Detected cardinality: "1:m"
#> Right duplicates: 1 key(s)
```

This returns a string like `"1:m"` that you can use programmatically.
You might use this in a script to select the right `expect` value for
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
dynamically, or to log the cardinality of a join for monitoring
purposes.

## Advanced Features

### Cartesian Product Detection

When both tables have duplicates on the same key, a join produces the
Cartesian product of those duplicates. Two keys with 100 rows each?
10,000 rows for that key alone.
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
warns you before this happens:

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
factor must be before a warning is triggered. Set it lower for
interactive work where you want early warnings; set it higher in batch
scripts where moderate expansion is expected and you only want to catch
truly pathological cases.

### Multi-Table Join Chains

[`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md)
runs diagnostics across a sequence of joins. You provide a named list of
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

Each step prints a diagnostic report. The special name `"result"` in the
second step refers to the output of the previous join, so you can chain
as many tables as needed. This placeholder is resolved internally: after
the first join produces an intermediate table, `"result"` is swapped in
as the left (or right) table for the next step. This means key
diagnostics at step two operate on the actual intermediate data, not on
the original input, which is important because the first join may have
introduced NAs or changed the key distribution.

### Backend Support

All join wrappers and
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
accept a `backend` argument. By default (`backend = NULL`), joinspy
detects the backend from the input class: tibbles use dplyr, data.tables
use data.table, and plain data frames use base R. You can override this:

``` r

# Force dplyr backend even for plain data frames
left_join_spy(x, y, by = "id", backend = "dplyr")

# Force base R for tibbles
left_join_spy(x, y, by = "id", backend = "base")
```

The three backends are `"base"`, `"dplyr"`, and `"data.table"`. The
diagnostic layer is backend-agnostic; all string analysis and key
checking happens before the join engine is invoked, so the reports are
identical regardless of which backend performs the actual merge.

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
