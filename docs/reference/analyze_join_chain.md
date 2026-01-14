# Analyze Multi-Table Join Chain

Analyzes a sequence of joins to identify potential issues in the chain.
Useful for debugging complex multi-table joins.

## Usage

``` r
analyze_join_chain(tables, joins)
```

## Arguments

- tables:

  A named list of data frames to join.

- joins:

  A list of join specifications, each with elements:

  left

  :   Name of left table

  right

  :   Name of right table

  by

  :   Join column(s)

## Value

A summary of the join chain analysis.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)

## Examples

``` r
orders <- data.frame(order_id = 1:3, customer_id = c(1, 2, 2))
customers <- data.frame(customer_id = 1:3, region_id = c(1, 1, 2))
regions <- data.frame(region_id = 1:2, name = c("North", "South"))

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
#> Left: 3 rows
#> Right: 3 rows
#> Match rate: 100%
#> Expected result: 3 rows (left join)
#> ! 1 issue(s) detected
#> 
#> 
#> ── Step 2: result + regions ──
#> 
#> Left: 9 rows
#> Right: 2 rows
#> Match rate: 100%
#> Expected result: 9 rows (left join)
#> ! 1 issue(s) detected
#> 
#> 
#> ── Chain Summary ──
#> 
#> ! Total issues across chain: 2
```
