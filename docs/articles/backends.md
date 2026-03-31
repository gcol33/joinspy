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

This vignette explains how detection works, when to override it, and
what happens to the output class through the diagnostic-repair-join
cycle.

## Auto-detection

When you call
[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)
or
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
without specifying a backend, joinspy inspects the class of `x` and `y`
and picks the backend according to a fixed priority:

1.  If either input inherits from `data.table`, use data.table.
    Otherwise, if either input inherits from `tbl_df` (tibble), use
    dplyr.

2.  If neither condition holds, use base R
    [`merge()`](https://rdrr.io/r/base/merge.html).

data.table wins over tibble because data.table’s merge implementation
has specific expectations about key handling and indexing that cannot be
replicated through dplyr’s join functions. A data.table joined via dplyr
loses its keys, its index, and its reference semantics, all properties
that the caller likely depends on if they chose data.table in the first
place. dplyr, by contrast, handles a data.table coerced to a tibble
without issues. So when the two classes conflict, data.table is the
safer default. When both inputs are plain data frames, base R is the
only dependency-free option and is always available.

The detection examines both inputs, not just `x`. Pipelines sometimes
pass a tibble on one side and a plain data frame on the other (for
instance, reading one table from a CSV with
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) and another with
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)).
As long as one side is a tibble, dplyr is selected, which avoids the
subtle differences in column ordering and NA handling between
[`merge()`](https://rdrr.io/r/base/merge.html) and
[`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html).

What happens when a mixed-class call selects a backend whose package is
not installed? joinspy falls back to base R and emits a warning. The
most common trigger is a data.table object lingering in an environment
where the data.table package was loaded transiently (e.g., via another
package) but is no longer available. The warning is loud on purpose: a
silent fallback could change the result’s class and break downstream
code.

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

When would you use this? A few common scenarios:

**Forcing dplyr on plain data frames.** If you want tibble output (with
its stricter printing and no partial matching) but your inputs are plain
data frames, pass `backend = "dplyr"`:

``` r

result <- left_join_spy(orders_df, customers_df, by = "id",
                        backend = "dplyr", .quiet = TRUE)
class(result)
#> [1] "data.frame"
```

**Forcing base R to avoid dplyr warnings.** dplyr 1.1.0 introduced a
many-to-many warning for joins that produce Cartesian products. If you
have already diagnosed the cardinality with
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
or
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
and know the expansion is intentional, you can bypass the dplyr warning
by forcing `backend = "base"`:

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

**Forcing data.table for speed on large data.** If you have plain data
frames with millions of rows, the data.table merge engine is
substantially faster than base R or dplyr. Passing
`backend = "data.table"` triggers the conversion internally; the result
comes back as a data.table.

``` r

result <- left_join_spy(orders_df, customers_df, by = "id",
                        backend = "data.table", .quiet = TRUE)
class(result)
#> [1] "data.table" "data.frame"
```

Note that the explicit backend must be installed. Requesting
`backend = "dplyr"` when dplyr is not installed will error, not silently
fall back. This is intentional: an explicit choice should fail loudly if
it cannot be honored. The asymmetry with auto-detection (which does fall
back silently) is deliberate. Auto-detection is a convenience; an
explicit override is a contract.

One more use case worth mentioning: **reproducibility across
environments.** If your script must produce identical output on a
colleague’s machine that may or may not have dplyr installed, set
`backend = "base"` explicitly. This removes the class of the input as a
variable and guarantees that the join always uses
[`merge()`](https://rdrr.io/r/base/merge.html), regardless of whether
someone upstream happened to return a tibble or a plain data frame.

## Class preservation

joinspy preserves input class through the full diagnostic-repair-join
cycle. The three stages behave as follows:

- **Diagnostics**
  ([`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
  [`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
  [`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md),
  etc.) accept any data frame subclass and return report objects. They
  do not modify or convert the input data.
- **Repair**
  ([`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md))
  operates on the key columns in place and returns the same class it
  received.
- **Join wrappers**
  ([`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
  [`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md),
  etc.) dispatch to the native join engine for the detected class, so
  the result matches the input class.

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

One edge case to be aware of: when you use
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
with both `x` and `y` arguments, it returns a list with `$x` and `$y`.
Each element preserves the class of the corresponding input. If `x` is a
tibble and `y` is a plain data frame, you get a tibble in `$x` and a
data frame in `$y`.

Class preservation also extends to
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md).
The cardinality check happens before the join, so if the constraint is
satisfied the result has the same class as the inputs, and if the
constraint is violated no result is returned at all (the function
errors). There is no intermediate state where the class might be lost.

The one place where class can change is when you use an explicit backend
override that does not match the input class. Passing
`backend = "data.table"` on a tibble will return a data.table, because
the data.table merge engine produces data.table output. Since you asked
for the data.table engine, that is what you get. Pass
`backend = "dplyr"` instead if you need a tibble back.

## Diagnostics are backend-agnostic

The diagnostic functions
([`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md),
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md),
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md),
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md))
operate purely on column values. They do not call any join engine. This
means they produce identical results whether the input is a data frame,
tibble, or data.table.

This separation is useful in practice. You can diagnose with
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
on a data.table, then join with dplyr if you prefer its output format.
Or diagnose in a script where only base R is available, then pass the
data to a Shiny app that uses dplyr internally. The diagnostic report
does not carry any backend dependency.

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

The report from
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
is the same object regardless of input class. Its `$issues`,
`$expected_rows`, and `$match_analysis` fields contain the same values;
only the join execution step (called separately via the wrappers)
depends on the backend. This also means you can write unit tests for
your key quality using plain data frames even if your production code
uses data.table. The diagnostic output is structurally identical, so
assertions on `report$issues` or `report$match_analysis$match_rate` will
hold regardless of the class used at test time versus production time.
You avoid pulling in heavy Suggests dependencies just to test key
diagnostics.

## Which backend to choose

joinspy does not have a preferred backend. It respects whatever you are
already using. Here is a brief orientation for cases where you do need
to choose.

**Base R** has no dependencies and is always available. It uses
[`merge()`](https://rdrr.io/r/base/merge.html), which handles all four
join types and named `by` vectors for different column names. The output
is always a plain data frame. Row order is not guaranteed (it depends on
the key sort), and [`merge()`](https://rdrr.io/r/base/merge.html)
reorders columns to put the key first. For small to medium datasets (up
to a few hundred thousand rows), base R is perfectly adequate.

**dplyr** is the standard in tidyverse workflows. It preserves column
order and row order from the left table, returns tibbles, and prints
compactly. It requires the dplyr package (and transitively tibble and
several others). Since dplyr 1.1.0, it also warns about many-to-many
joins, which is helpful as a safety net but can be noisy if you have
already diagnosed the cardinality with joinspy.

**data.table** is the fastest option for large datasets. Its merge
implementation is heavily optimized and can handle tens of millions of
rows efficiently. The tradeoff is reference semantics: data.table
modifies objects in place in some operations, which can surprise users
accustomed to R’s copy-on-modify behavior. joinspy’s data.table backend
uses [`merge()`](https://rdrr.io/r/base/merge.html) (not the
`[.data.table` join syntax), so it avoids most reference-semantic
surprises, but the result is still a data.table object with data.table’s
printing and subsetting behavior.

A practical consideration: the three backends differ in how they handle
column name collisions. When `x` and `y` share non-key column names,
base R appends `.x` and `.y` suffixes, dplyr appends `.x` and `.y` by
default (configurable via `suffix`), and data.table appends `i.` to the
columns from the right table. These suffixes affect downstream code that
references the merged columns by name. If you switch backends
mid-project, check that column references still resolve correctly.

Another difference is row ordering. Base R’s
[`merge()`](https://rdrr.io/r/base/merge.html) sorts rows by the key
column. dplyr preserves the row order of the left table. data.table
sorts by key if the tables are keyed, and otherwise preserves insertion
order. For most analytical workflows the order does not matter, but if
you are comparing output across backends in tests or reproducibility
checks, sort the result before comparing.

The simplest rule: use what your project already depends on. If you have
no preference, base R is the safest default. If performance matters,
data.table. If you want tibble output and tidyverse compatibility,
dplyr.

## See Also

- [`vignette("quickstart")`](https://gillescolling.com/joinspy/articles/quickstart.md)
  for a quick introduction to joinspy

- [`vignette("common-issues")`](https://gillescolling.com/joinspy/articles/common-issues.md)
  for a catalogue of join problems and solutions

- [`?left_join_spy`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)
  for backend parameter documentation
