# Explain Row Count Changes After a Join

After performing a join, use this function to understand why the row
count changed. It analyzes the original tables and the result to explain
the difference.

## Usage

``` r
join_explain(result, x, y, by, type = NULL)
```

## Arguments

- result:

  The result of a join operation.

- x:

  The original left data frame.

- y:

  The original right data frame.

- by:

  A character vector of column names used in the join.

- type:

  Character. The type of join that was performed. One of `"left"`,
  `"right"`, `"inner"`, `"full"`. If `NULL` (default), attempts to infer
  the join type from row counts.

## Value

Invisibly returns a list with explanation details. Prints a
human-readable explanation.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md)

## Examples

``` r
orders <- data.frame(id = c(1, 2, 2, 3), value = 1:4)
customers <- data.frame(id = c(1, 2, 2, 4), name = c("A", "B1", "B2", "D"))

result <- merge(orders, customers, by = "id", all.x = TRUE)

# Explain why we got more rows than expected
join_explain(result, orders, customers, by = "id", type = "left")
#> 
#> ── Join Explanation ────────────────────────────────────────────────────────────
#> 
#> ── Row Counts ──
#> 
#> Left table (x): 4 rows
#> Right table (y): 4 rows
#> Result: 6 rows
#> ! Result has 2 more rows than left table
#> 
#> 
#> ── Why the row count changed ──
#> 
#> ℹ Both tables have duplicate keys - this causes multiplicative row expansion
#> ℹ 1 left key(s) have no match in right table
```
