# Comprehensive Pre-Join Diagnostic Report

Analyzes two data frames before joining to detect potential issues and
predict the outcome. Returns a detailed report of key quality, match
rates, and detected problems.

## Usage

``` r
join_spy(x, y, by, sample = NULL, ...)
```

## Arguments

- x:

  A data frame (left table in the join).

- y:

  A data frame (right table in the join).

- by:

  A character vector of column names to join by, or a named character
  vector for joins where column names differ (e.g.,
  `c("id" = "customer_id")`).

- sample:

  Integer or NULL. If provided, randomly sample this many rows from each
  table for faster diagnostics on large datasets. Default NULL (analyze
  all rows).

- ...:

  Reserved for future use.

## Value

A `JoinReport` object with the following components:

- x_summary:

  Summary statistics for keys in the left table

- y_summary:

  Summary statistics for keys in the right table

- match_analysis:

  Details of which keys will/won't match

- issues:

  List of detected problems (duplicates, whitespace, etc.)

- expected_rows:

  Predicted row counts for each join type

## Details

This function detects the following common join issues:

- **Duplicate keys**: Keys appearing multiple times, which cause row
  multiplication during joins

- **Whitespace**: Leading or trailing spaces that prevent matches

- **Case mismatches**: Keys that differ only by case (e.g., "ABC" vs
  "abc")

- **Encoding issues**: Different character encodings or invisible
  Unicode characters

- **NA values**: Missing values in key columns

## See also

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md),
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)

## Examples

``` r
# Create sample data with issues
orders <- data.frame(
  order_id = 1:5,
  customer_id = c("A", "B", "B", "C", "D ")
)
customers <- data.frame(
  customer_id = c("A", "B", "C", "E"),
  name = c("Alice", "Bob", "Carol", "Eve")
)

# Get diagnostic report
join_spy(orders, customers, by = "customer_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: customer_id
#> 
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 5 Unique keys: 4 Duplicate keys: 1 NA keys: 0
#> Right table: Rows: 4 Unique keys: 4 Duplicate keys: 0 NA keys: 0
#> 
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 3
#> Keys only in left: 1
#> Keys only in right: 1
#> Match rate (left): "75%"
#> 
#> 
#> ── Issues Detected ──
#> 
#> ! Left table has 1 duplicate key(s) affecting 2 rows - may cause row multiplication
#> ! Left column 'customer_id' has 1 value(s) with leading/trailing whitespace
#> 
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 4
#> left_join: 5
#> right_join: 5
#> full_join: 6
```
