# Full Join with Diagnostics

Performs a full join and automatically prints diagnostic information.

## Usage

``` r
full_join_spy(x, y, by, verbose = TRUE, .quiet = FALSE, backend = NULL, ...)
```

## Arguments

- x:

  A data frame (left table).

- y:

  A data frame (right table).

- by:

  A character vector of column names to join by.

- verbose:

  Logical. If `TRUE` (default), prints diagnostic summary.

- .quiet:

  Logical. If `TRUE`, suppresses all output (overrides `verbose`).
  Useful for silent pipeline operations. Use
  [`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
  to access the diagnostics afterward.

- backend:

  Character or `NULL`. The join backend to use. If `NULL` (default),
  auto-detects from input class: `data.table` inputs use data.table,
  tibble inputs use dplyr, otherwise base R
  [`merge()`](https://rdrr.io/r/base/merge.html). Explicit values:
  `"base"`, `"dplyr"`, `"data.table"`.

- ...:

  Additional arguments passed to the underlying join function.

## Value

The joined data frame with a `"join_report"` attribute.

## See also

[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
