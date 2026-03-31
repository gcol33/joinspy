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

We walk through detection, explicit overrides, and class preservation
below.

## Auto-detection

When we call
[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)
or
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
without specifying a backend, joinspy inspects the class of `x` and `y`
and picks the backend according to a fixed priority: data.table \>
tibble \> base R.

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

Or force base R to sidestep dplyr’s many-to-many warning when we already
know the expansion is intentional:

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

# Force base R to avoid dplyr's many-to-many warning
result <- left_join_spy(tags, prices, by = "item_id",
                        backend = "base", .quiet = TRUE)
nrow(result)
#> [1] 4
```

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

## Backend differences at a glance

The three backends differ in a few ways worth noting:

- **Column name collisions.** Base R and dplyr append `.x`/`.y`
  suffixes; data.table appends `i.` to right-table columns.
- **Row ordering.** Base R sorts by key; dplyr preserves left-table
  order; data.table sorts by key if keyed, otherwise preserves insertion
  order.
- **Performance.** data.table is the fastest for large inputs. Base R
  and dplyr are comparable for small to medium datasets.

If we switch backends mid-project, it is worth checking that column
references and row-order assumptions still hold.

## See Also

- [`vignette("quickstart")`](https://gillescolling.com/joinspy/articles/quickstart.md)
  for a quick introduction to joinspy

- [`vignette("common-issues")`](https://gillescolling.com/joinspy/articles/common-issues.md)
  for a catalogue of join problems and solutions

- [`?left_join_spy`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)
  for backend parameter documentation
