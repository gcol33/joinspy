# Get the Last Join Report

Retrieves the most recent `JoinReport` object from any `*_join_spy()`
call. Useful when using `.quiet = TRUE` in pipelines and wanting to
inspect the diagnostics afterward.

## Usage

``` r
last_report()
```

## Value

The last `JoinReport` object, or `NULL` if no join has been performed.

## See also

[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)

## Examples

``` r
orders <- data.frame(id = 1:3, value = c(10, 20, 30))
customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))

# Silent join in a pipeline
result <- left_join_spy(orders, customers, by = "id", .quiet = TRUE)

# Inspect the report afterward
last_report()
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
