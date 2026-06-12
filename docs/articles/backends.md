# Working with Backends

joinspy works with base R data frames, tibbles, and data.tables. The
join wrappers
([`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md),
etc.) detect the input class and dispatch to the right engine
automatically. The diagnostic layer
([`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md),
and friends) is backend-agnostic: it runs the same analysis regardless
of what class the inputs are.

We walk through detection, the exact engine calls behind each wrapper,
explicit overrides, and class preservation below. We then take the
engine differences that survive the wrapper layer (column-name
collisions, row ordering, NA-key matching) and demonstrate each one with
output, so that switching backends mid-project holds no surprises. The
vignette closes with how backends interact with
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
and the report flow, and with guidance on when an override earns its
keep.

## Auto-detection

When we call
[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)
or
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
without specifying a backend, joinspy inspects the class of `x` and `y`
and picks the backend according to a fixed priority: data.table \>
tibble \> base R.

The check itself is two
[`inherits()`](https://rdrr.io/r/base/class.html) calls. A
`"data.table"` class on either input selects the data.table engine. When
neither side is a data.table, an input inheriting from `"tbl_df"` hands
the join to dplyr, and plain data frames fall through to base R, which
needs nothing beyond what ships with R. Both dplyr and data.table sit in
Suggests, so the base path works on an installation that has neither.

data.table takes priority because its merge implementation depends on
key handling, indexing, and reference semantics that a dplyr join would
discard. dplyr, on the other hand, handles a coerced data.table without
issues. Both inputs are checked – if one side is a tibble and the other
a plain data frame, dplyr is selected. If a mixed-class call selects a
backend whose package is not installed, joinspy falls back to base R
with a warning.

Here is the detection in action with each input type:

``` r

# Base R data frames: auto-detects "base"
orders_df <- data.frame(
  id = c(1, 2, 3),
  amount = c(100, 250, 75),
  stringsAsFactors = FALSE
)

customers_df <- data.frame(
  id = c(1, 2, 4),
  name = c("Alice", "Bob", "Diana"),
  stringsAsFactors = FALSE
)

result_base <- left_join_spy(orders_df, customers_df, by = "id", .quiet = TRUE)
class(result_base)
#> [1] "data.frame"
```

``` r

# Tibbles: auto-detects "dplyr"
orders_tbl <- dplyr::tibble(
  id = c(1, 2, 3),
  amount = c(100, 250, 75)
)

customers_tbl <- dplyr::tibble(
  id = c(1, 2, 4),
  name = c("Alice", "Bob", "Diana")
)

result_dplyr <- left_join_spy(orders_tbl, customers_tbl, by = "id", .quiet = TRUE)
class(result_dplyr)
#> [1] "tbl_df"     "tbl"        "data.frame"
```

``` r

# data.tables: auto-detects "data.table"
orders_dt <- data.table::data.table(
  id = c(1, 2, 3),
  amount = c(100, 250, 75)
)

customers_dt <- data.table::data.table(
  id = c(1, 2, 4),
  name = c("Alice", "Bob", "Diana")
)

result_dt <- left_join_spy(orders_dt, customers_dt, by = "id", .quiet = TRUE)
class(result_dt)
#> [1] "data.table" "data.frame"
```

When the two inputs have different classes, the higher-priority class
wins:

``` r

# data.table + tibble: data.table wins
mixed_result <- left_join_spy(orders_dt, customers_tbl, by = "id", .quiet = TRUE)
class(mixed_result)
#> [1] "data.table" "data.frame"
```

A single data.table anywhere in the call decides the engine, even when
the other input is a tibble.

## From wrapper to engine call

All five joining functions route through one internal dispatch point, so
backend behavior is identical whether we call a `*_join_spy()` wrapper
or
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md).
The dispatch maps each join type onto the engine’s own interface:

| joinspy call | `"base"` | `"dplyr"` | `"data.table"` |
|----|----|----|----|
| [`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md) | `merge(x, y, all.x = TRUE)` | `dplyr::left_join(x, y, by)` | `merge(xdt, ydt, all.x = TRUE)` |
| [`right_join_spy()`](https://gillescolling.com/joinspy/reference/right_join_spy.md) | `merge(x, y, all.y = TRUE)` | `dplyr::right_join(x, y, by)` | `merge(xdt, ydt, all.y = TRUE)` |
| [`inner_join_spy()`](https://gillescolling.com/joinspy/reference/inner_join_spy.md) | `merge(x, y)` | `dplyr::inner_join(x, y, by)` | `merge(xdt, ydt, all = FALSE)` |
| [`full_join_spy()`](https://gillescolling.com/joinspy/reference/full_join_spy.md) | `merge(x, y, all.x = TRUE, all.y = TRUE)` | `dplyr::full_join(x, y, by)` | `merge(xdt, ydt, all = TRUE)` |
| `join_strict(type = ...)` | as above, for `type` | as above | as above |

In the data.table column, `xdt` and `ydt` are the inputs after
[`data.table::as.data.table()`](https://rdrr.io/pkg/data.table/man/as.data.table.html),
which passes an existing data.table through unchanged. The data.table
engine therefore goes through `merge.data.table()`, the method
data.table registers for base R’s
[`merge()`](https://rdrr.io/r/base/merge.html) generic. It never touches
the `y[x]` bracket-join syntax. Several behaviors people associate with
data.table joins (the `i.` column prefix, joining on the table’s stored
key) belong to the bracket syntax and do not appear here.

A named `by` vector such as `c("id" = "customer_id")` works on every
backend. Base R receives it as `by.x` and `by.y`, dplyr takes the named
vector natively, and for data.table the right table’s key columns are
renamed to the left table’s names before merging. In all three cases the
result carries the left table’s key names; the right table’s name
(`account_key` below) never surfaces in the output, whichever engine
runs:

``` r

accounts <- data.frame(id = c(1, 2), balance = c(50, 80))
holders <- data.frame(account_key = c(1, 2), holder = c("Ana", "Ben"))

names(left_join_spy(accounts, holders, by = c("id" = "account_key"),
                    backend = "data.table", .quiet = TRUE))
#> [1] "id"      "balance" "holder"
```

Anything passed through `...` lands in the engine call from the table
above. That is the door for engine-specific arguments, several of which
appear in the sections that follow: `sort`, `suffixes`, and
`incomparables` for the two
[`merge()`](https://rdrr.io/r/base/merge.html)-based engines;
`na_matches`, `suffix`, and `relationship` for dplyr.

## Explicit override

All join wrappers and
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
accept a `backend` argument that overrides auto-detection. The three
valid values are `"base"`, `"dplyr"`, and `"data.table"`.

We can force dplyr on plain data frames to get tibble output:

``` r

result <- left_join_spy(orders_df, customers_df, by = "id",
                        backend = "dplyr", .quiet = TRUE)
class(result)
#> [1] "data.frame"
```

Many-to-many keys are a place where the engines look like they should
diverge. Called at the console,
[`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
warns when it detects an unexpected many-to-many relationship. Through
joinspy no warning appears on any backend, because dplyr runs that check
only for joins called directly from the user’s environment; a call that
originates inside another package skips it. The joinspy report still
flags the expansion: it counts the duplicate keys and predicts the
multiplied row count before the engine runs.

``` r

# These have a legitimate many-to-many relationship
tags <- dplyr::tibble(
  item_id = c(1, 1, 2),
  tag = c("red", "large", "small")
)

prices <- dplyr::tibble(
  item_id = c(1, 2, 2),
  currency = c("USD", "USD", "EUR")
)

result <- left_join_spy(tags, prices, by = "item_id", .quiet = TRUE)
nrow(result)
#> [1] 4
```

Three input rows became four, silently as far as dplyr is concerned;
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
has the full story. To turn an expectation about key relationships into
a hard requirement, dplyr’s `relationship` argument passes through `...`
and keeps its teeth, since constraint violations are errors and errors
fire no matter who calls the join:

``` r

left_join_spy(tags, prices, by = "item_id", .quiet = TRUE,
              relationship = "one-to-one")
#> Error in `join_fn()`:
#> ! Each row in `y` must match at most 1 row in `x`.
#> ℹ Row 1 of `y` matches multiple rows in `x`.
```

`join_strict(expect = "1:1")` does the same job with a single syntax
across all three backends; we return to it below.

Or force data.table on plain data frames for speed on large inputs:

``` r

result <- left_join_spy(orders_df, customers_df, by = "id",
                        backend = "data.table", .quiet = TRUE)
class(result)
#> [1] "data.table" "data.frame"
```

An explicit backend must be installed. Requesting `backend = "dplyr"`
without dplyr will error, not silently fall back – auto-detection is a
convenience, but an explicit override is a contract.

Setting `backend = "base"` is also a way to guarantee reproducibility
across environments where dplyr may or may not be installed.

## Class preservation

joinspy preserves input class through the full diagnostic-repair-join
cycle:

- **Diagnostics**
  ([`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
  [`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
  etc.) accept any data frame subclass and return report objects without
  modifying the input.
- **Repair**
  ([`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md))
  operates on key columns in place and returns the same class it
  received.
- **Join wrappers** dispatch to the native join engine for the detected
  class.

Here is a full cycle with base R data frames:

``` r

messy_df <- data.frame(
  code = c("A-1 ", "B-2", " C-3"),
  value = c(10, 20, 30),
  stringsAsFactors = FALSE
)

lookup_df <- data.frame(
  code = c("A-1", "B-2", "C-3"),
  label = c("Alpha", "Beta", "Gamma"),
  stringsAsFactors = FALSE
)

# 1. Diagnose
report <- join_spy(messy_df, lookup_df, by = "code")

# 2. Repair
repaired_df <- join_repair(messy_df, by = "code")
#> ✔ Repaired 2 value(s)
class(repaired_df)  # still data.frame
#> [1] "data.frame"

# 3. Join
joined_df <- left_join_spy(repaired_df, lookup_df, by = "code", .quiet = TRUE)
class(joined_df)  # still data.frame
#> [1] "data.frame"
joined_df
#>   code value label
#> 1  A-1    10 Alpha
#> 2  B-2    20  Beta
#> 3  C-3    30 Gamma
```

The same cycle with tibbles:

``` r

messy_tbl <- dplyr::tibble(
  code = c("A-1 ", "B-2", " C-3"),
  value = c(10, 20, 30)
)

lookup_tbl <- dplyr::tibble(
  code = c("A-1", "B-2", "C-3"),
  label = c("Alpha", "Beta", "Gamma")
)

repaired_tbl <- join_repair(messy_tbl, by = "code")
#> ✔ Repaired 2 value(s)
class(repaired_tbl)  # still tbl_df
#> [1] "tbl_df"     "tbl"        "data.frame"

joined_tbl <- left_join_spy(repaired_tbl, lookup_tbl, by = "code", .quiet = TRUE)
class(joined_tbl)  # still tbl_df
#> [1] "tbl_df"     "tbl"        "data.frame"
joined_tbl
#> # A tibble: 3 × 3
#>   code  value label
#>   <chr> <dbl> <chr>
#> 1 A-1      10 Alpha
#> 2 B-2      20 Beta 
#> 3 C-3      30 Gamma
```

And with data.tables:

``` r

messy_dt <- data.table::data.table(
  code = c("A-1 ", "B-2", " C-3"),
  value = c(10, 20, 30)
)

lookup_dt <- data.table::data.table(
  code = c("A-1", "B-2", "C-3"),
  label = c("Alpha", "Beta", "Gamma")
)

repaired_dt <- join_repair(messy_dt, by = "code")
#> ✔ Repaired 2 value(s)
class(repaired_dt)  # still data.table
#> [1] "data.table" "data.frame"

joined_dt <- left_join_spy(repaired_dt, lookup_dt, by = "code", .quiet = TRUE)
class(joined_dt)  # still data.table
#> [1] "data.table" "data.frame"
joined_dt
#> Key: <code>
#>      code value  label
#>    <char> <num> <char>
#> 1:    A-1    10  Alpha
#> 2:    B-2    20   Beta
#> 3:    C-3    30  Gamma
```

When
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
receives both `x` and `y`, it returns a list with `$x` and `$y`, each
preserving the class of the corresponding input.

[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
also preserves class – the cardinality check runs before the join, so a
satisfied constraint returns the native class and a violated one errors
before any output is produced.

The one exception is an explicit backend override that does not match
the input class. Passing `backend = "data.table"` on a tibble returns a
data.table, because that is what the data.table engine produces.

## Backend differences, demonstrated

The wrapper layer hides the engine interfaces and normalizes the column
naming for named keys. The engines’ own conventions for the result pass
through untouched: how name collisions are resolved, what order rows
come back in, and whether NA keys match. Each of these is small enough
to go unnoticed in a code review and large enough to change downstream
results, so we show all three with output rather than assert them.

### Column-name collisions

When a non-key column exists in both tables, every engine has to rename
one of them. All three backends land on the same convention, the
`.x`/`.y` suffix pair:

``` r

dup_left <- data.frame(id = c(1, 2), status = c("open", "closed"))
dup_right <- data.frame(id = c(1, 2), status = c("new", "old"))

names(left_join_spy(dup_left, dup_right, by = "id", .quiet = TRUE))
#> [1] "id"       "status.x" "status.y"
```

``` r

names(left_join_spy(dup_left, dup_right, by = "id",
                    backend = "dplyr", .quiet = TRUE))
#> [1] "id"       "status.x" "status.y"
```

``` r

names(left_join_spy(dup_left, dup_right, by = "id",
                    backend = "data.table", .quiet = TRUE))
#> [1] "id"       "status.x" "status.y"
```

data.table users may expect an `i.` prefix on right-table columns. That
prefix comes from the `y[x]` bracket join; `merge.data.table()` follows
the suffix convention of base R’s
[`merge()`](https://rdrr.io/r/base/merge.html), and the data.table
backend calls [`merge()`](https://rdrr.io/r/base/merge.html). Column
names in joinspy output are stable across backends.

The suffix pair is configurable through `...`, with one spelling
difference to keep in mind when migrating code: both
[`merge()`](https://rdrr.io/r/base/merge.html) methods call the argument
`suffixes`, dplyr calls it `suffix`.

``` r

names(left_join_spy(dup_left, dup_right, by = "id", backend = "dplyr",
                    .quiet = TRUE, suffix = c("_current", "_incoming")))
#> [1] "id"              "status_current"  "status_incoming"
```

### Row ordering

Row order is the difference most likely to break code silently. Base R’s
[`merge()`](https://rdrr.io/r/base/merge.html) sorts the result by the
key columns. So does `merge.data.table()`, whose `sort` argument
defaults to `TRUE`. dplyr keeps the left table’s row order. We join a
left table whose ids arrive in the order 3, 1, 2:

``` r

lhs <- data.frame(id = c(3, 1, 2), amount = c(30, 10, 20))
rhs <- data.frame(id = c(1, 2, 3), name = c("a", "b", "c"))

left_join_spy(lhs, rhs, by = "id", .quiet = TRUE)$id
#> [1] 1 2 3
```

``` r

left_join_spy(lhs, rhs, by = "id", backend = "dplyr", .quiet = TRUE)$id
#> [1] 3 1 2
```

``` r

left_join_spy(lhs, rhs, by = "id", backend = "data.table", .quiet = TRUE)$id
#> [1] 1 2 3
```

Only dplyr returns the rows the way they arrived. For the merge-based
engines, `sort = FALSE` passes through `...`:

``` r

left_join_spy(lhs, rhs, by = "id", backend = "data.table",
              .quiet = TRUE, sort = FALSE)$id
#> [1] 3 1 2
```

data.table documents the unsorted result as keeping `x`’s row order.
Base R documents it as unspecified, so unsorted
[`merge()`](https://rdrr.io/r/base/merge.html) output should be treated
as arbitrary even when it happens to look right. Any pipeline that
indexes join output by row position will give different answers under
base or data.table than under dplyr; an explicit
[`order()`](https://rdrr.io/r/base/order.html) after the join, or
joining on a key downstream instead of relying on position, makes the
assumption visible and removes the hazard.

### NA keys match each other

All three engines treat NA as a matchable value by default. An NA key on
the left joins to an NA key on the right:

``` r

na_left <- data.frame(code = c("A", NA), v = c(1, 2))
na_right <- data.frame(code = c("A", NA), label = c("alpha", "missing"))

nrow(inner_join_spy(na_left, na_right, by = "code", .quiet = TRUE))
#> [1] 2
```

``` r

nrow(inner_join_spy(na_left, na_right, by = "code",
                    backend = "dplyr", .quiet = TRUE))
#> [1] 2
```

``` r

inner_join_spy(na_left, na_right, by = "code",
               backend = "data.table", .quiet = TRUE)
#> Key: <code>
#>      code     v   label
#>    <char> <num>  <char>
#> 1:   <NA>     2 missing
#> 2:      A     1   alpha
```

Two rows on every backend; the NA-to-NA pair survives the inner join.
The data.table output also shows its key sort placing the NA row first.

joinspy’s row predictions take the opposite stance.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
counts NA keys separately, reports them as an issue, and predicts row
counts as if they match nothing:

``` r

report <- join_spy(na_left, na_right, by = "code")
report$expected_rows$inner
#> [1] 1
```

The predicted inner join has 1 row; the engines return 2. In a verbose
wrapper call this surfaces as a `Result: 2 rows (expected 1)` flag,
which is exactly the discrepancy the wrapper exists to catch, since
NA-on-NA matches are a classic source of phantom rows. To make the
engines agree with the prediction, two pass-through arguments drop NA
matches: `na_matches = "never"` for dplyr, and `incomparables = NA` for
both [`merge()`](https://rdrr.io/r/base/merge.html)-based engines
(single-key joins only):

``` r

nrow(inner_join_spy(na_left, na_right, by = "code", backend = "dplyr",
                    .quiet = TRUE, na_matches = "never"))
#> [1] 1
```

``` r

nrow(inner_join_spy(na_left, na_right, by = "code", backend = "base",
                    .quiet = TRUE, incomparables = NA))
#> [1] 1
```

For composite keys, where `incomparables` no longer applies, filtering
NA keys before the join with
[`complete.cases()`](https://rdrr.io/r/stats/complete.cases.html) on the
key columns is the portable route. The report’s NA-key counts say up
front how many rows such a filter would touch.

## join_strict(), .quiet, and the report flow

Every wrapper computes the diagnostic report before any engine runs. All
four `*_join_spy()` functions share one implementation that calls
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
first, stores the result, and only then dispatches the join. The
`backend` argument affects the second step alone, so the report is
identical whichever engine performs the join:

``` r

invisible(left_join_spy(orders_df, customers_df, by = "id",
                        backend = "base", .quiet = TRUE))
report_base <- last_report()

invisible(left_join_spy(orders_df, customers_df, by = "id",
                        backend = "dplyr", .quiet = TRUE))
report_dplyr <- last_report()

identical(report_base$expected_rows, report_dplyr$expected_rows)
#> [1] TRUE
```

`.quiet = TRUE` suppresses the printing and nothing else. The report is
still computed. It remains available through
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md),
travels with the result as the `"join_report"` attribute, and goes to
the log whenever
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
is active. A quiet data.table join leaves the same audit trail as a
verbose dplyr one.

``` r

result <- left_join_spy(orders_df, customers_df, by = "id", .quiet = TRUE)
is_join_report(attr(result, "join_report"))
#> [1] TRUE
```

In verbose mode the wrapper finishes by comparing the engine’s actual
row count against the report’s prediction for the chosen join type.
Because the prediction is backend-independent, this check doubles as a
guard against the engine differences from the previous section: an NA
key that matched, or a duplicate that multiplied, shows up as a
predicted-versus-actual gap whatever the backend.

[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
slots into the same flow one step earlier. It summarizes the keys,
classifies the actual cardinality, and raises an error before any engine
is chosen when the `expect` contract is violated. The error message is
the same on every backend because no backend has run yet. Here we
request data.table and still fail at the cardinality gate:

``` r

products <- data.frame(id = 1:3, product = c("A", "B", "C"))
suppliers_dup <- data.frame(id = c(1, 1, 2), name = c("S1", "S2", "S3"))

join_strict(products, suppliers_dup, by = "id", expect = "1:1",
            backend = "data.table")
#> Error in `join_strict()`:
#> ! Cardinality violation: expected "1:1" but found "1:n".
#> ℹ Left duplicates: 0, right duplicates: 1.
```

When the contract holds, the join proceeds through the same dispatch as
the wrappers and returns the native class:

``` r

products_dt <- data.table::data.table(id = 1:3, product = c("A", "B", "C"))
suppliers_dt <- data.table::data.table(id = 1:3, name = c("S1", "S2", "S3"))

class(join_strict(products_dt, suppliers_dt, by = "id", expect = "1:1"))
#> [1] "data.table" "data.frame"
```

## Diagnostics are backend-agnostic

The diagnostic functions
([`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md),
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md),
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md),
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md))
operate purely on column values and never call a join engine. They
produce identical results regardless of input class.

This means we can diagnose on data.tables and join with dplyr, or
diagnose in a base-R script and pass the data to a Shiny app that uses
dplyr internally.

``` r

# Diagnose on data.tables
orders_dt <- data.table::data.table(
  id = c(1, 2, 3),
  amount = c(100, 250, 75)
)

customers_dt <- data.table::data.table(
  id = c(1, 2, 4),
  name = c("Alice", "Bob", "Diana")
)

report <- join_spy(orders_dt, customers_dt, by = "id")

# Join with dplyr (convert first)
orders_tbl <- dplyr::as_tibble(orders_dt)
customers_tbl <- dplyr::as_tibble(customers_dt)
result <- left_join_spy(orders_tbl, customers_tbl, by = "id", .quiet = TRUE)
class(result)
#> [1] "tbl_df"     "tbl"        "data.frame"
```

The report object is structurally identical across backends – `$issues`,
`$expected_rows`, and `$match_analysis` contain the same values. This
also means we can write unit tests for key quality using plain data
frames even when production code uses data.table.

## Choosing a backend

Auto-detection is the right default. It keeps the output class aligned
with the input class, it never errors over a missing package, and the
same script behaves sensibly whether a colleague feeds it tibbles or
data.tables. The override is for cases where the engine itself matters.

`backend = "base"` removes dplyr and data.table from the execution path.
A script that must run on a minimal R installation, a package that wants
joinspy without inheriting heavier dependencies, and a frozen
reproducibility archive are all served by base R’s
[`merge()`](https://rdrr.io/r/base/merge.html), whose join semantics
have been stable for decades. Forcing base is also one way to reach
[`merge()`](https://rdrr.io/r/base/merge.html)-only arguments on inputs
that would otherwise auto-detect to dplyr.

`backend = "dplyr"` buys the `relationship` and `na_matches` controls
shown above, plus tibble output for pipelines that expect it. When the
surrounding code is dplyr anyway, matching the backend keeps a single
join grammar in play.

`backend = "data.table"` matters when the output feeds by-reference
operations (`:=`,
[`data.table::setkey()`](https://rdrr.io/pkg/data.table/man/setkey.html))
that require a genuine data.table, or when the tables are large enough
for engine speed to register at all. Inside joinspy that point arrives
later than expected, because the wrapper spends most of its time on
diagnostics rather than on the join. We can measure this directly: the
chunk times the same 5,000-row join on each backend, then times the
diagnostic pass alone.

``` r

set.seed(42)
n <- 5000
big_x <- data.frame(id = sample(n), x = rnorm(n))
big_y <- data.frame(id = sample(n), y = rnorm(n))

t_base <- system.time(left_join_spy(big_x, big_y, by = "id",
                                    backend = "base", .quiet = TRUE))
t_dplyr <- system.time(left_join_spy(big_x, big_y, by = "id",
                                     backend = "dplyr", .quiet = TRUE))
t_dt <- system.time(left_join_spy(big_x, big_y, by = "id",
                                  backend = "data.table", .quiet = TRUE))
t_spy <- system.time(report <- join_spy(big_x, big_y, by = "id"))

round(c(base = t_base[["elapsed"]], dplyr = t_dplyr[["elapsed"]],
        data.table = t_dt[["elapsed"]], diagnostics = t_spy[["elapsed"]]), 3)
#>        base       dplyr  data.table diagnostics 
#>        0.31        0.29        0.30        0.55
```

The three wrapper timings land close together, and the last entry shows
why: most of the elapsed time is
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
scanning keys, with the engine merge accounting for the remainder. Two
consequences follow. Switching backends to speed up a `*_join_spy()`
call addresses the smaller term. And on genuinely large tables the lever
sits on the diagnostic side:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
accepts a `sample` argument for approximate diagnostics on a row subset,
after which the engine of choice can be called directly on the full
data.

Two cautions before overriding. First, an explicit backend determines
the output class regardless of input class: `backend = "data.table"` on
tibbles returns a data.table, and downstream tibble-flavored code may
misbehave. Second, `backend = "base"` selects base R’s
[`merge()`](https://rdrr.io/r/base/merge.html) generic, and S3 dispatch
inside [`merge()`](https://rdrr.io/r/base/merge.html) still routes
data.table inputs to data.table’s own method:

``` r

class(left_join_spy(orders_dt, customers_dt, by = "id",
                    backend = "base", .quiet = TRUE))
#> [1] "data.table" "data.frame"
```

A data.table input runs `merge.data.table()` even under
`backend = "base"`. Stripping the class first with
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) is the
way to reach the data.frame method. The same dispatch rule applies to
tibbles, harmlessly: tibbles register no
[`merge()`](https://rdrr.io/r/base/merge.html) method of their own, so
the data.frame method runs. Auto-detection already picks the engine that
respects the richest input class, which is why leaving the `backend`
argument alone is the recommendation for everything except the
deliberate cases above.

## See Also

- [`vignette("quickstart")`](https://gillescolling.com/joinspy/articles/quickstart.md)
  for a quick introduction to joinspy

- [`vignette("common-issues")`](https://gillescolling.com/joinspy/articles/common-issues.md)
  for a catalogue of join problems and solutions

- [`?left_join_spy`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)
  for backend parameter documentation
