# Left Join with Diagnostics

Performs a left join and automatically prints diagnostic information
about the operation. The diagnostic report is also attached as an
attribute.

## Usage

``` r
left_join_spy(x, y, by, verbose = TRUE, .quiet = FALSE, ...)
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

- ...:

  Additional arguments passed to the underlying join function.

## Value

The joined data frame with a `"join_report"` attribute containing the
diagnostic information.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md),
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)

## Examples

``` r
orders <- data.frame(id = 1:3, value = c(10, 20, 30))
customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))

result <- left_join_spy(orders, customers, by = "id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: id
#> 
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 1
#> Keys only in right: 1
#> Match rate (left): "66.7%"
#> 
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 3
#> right_join: 3
#> full_join: 4
#> 
#> ℹ Performing "left" join...
#> ✔ Result: 3 rows (as expected)

# Access the diagnostic report
attr(result, "join_report")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: id
#> 
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 1
#> Keys only in right: 1
#> Match rate (left): "66.7%"
#> 
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 3
#> right_join: 3
#> full_join: 4

# Silent mode for pipelines
result2 <- left_join_spy(orders, customers, by = "id", .quiet = TRUE)
last_report()  # Access diagnostics afterward
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: id
#> 
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 1
#> Keys only in right: 1
#> Match rate (left): "66.7%"
#> 
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 3
#> right_join: 3
#> full_join: 4
```
