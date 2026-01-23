# Summary Method for JoinReport

Returns a compact summary data frame of the join diagnostic report.

## Usage

``` r
# S3 method for class 'JoinReport'
summary(object, format = c("data.frame", "text", "markdown"), ...)
```

## Arguments

- object:

  A `JoinReport` object.

- format:

  Output format: "data.frame" (default), "text", or "markdown".

- ...:

  Additional arguments (ignored).

## Value

A data frame with key metrics (or printed output for text/markdown).

## Examples

``` r
orders <- data.frame(id = 1:5, val = 1:5)
customers <- data.frame(id = 3:7, name = letters[3:7])

report <- join_spy(orders, customers, by = "id")
summary(report)
#>               metric value
#> 1          left_rows   5.0
#> 2         right_rows   5.0
#> 3   left_unique_keys   5.0
#> 4  right_unique_keys   5.0
#> 5       keys_matched   3.0
#> 6     keys_left_only   2.0
#> 7    keys_right_only   2.0
#> 8         match_rate   0.6
#> 9             issues   0.0
#> 10   inner_join_rows   3.0
#> 11    left_join_rows   5.0
#> 12   right_join_rows   5.0
#> 13    full_join_rows   7.0
summary(report, format = "markdown")
#> | Metric | Value |
#> |--------|-------|
#> | left_rows | 5 |
#> | right_rows | 5 |
#> | left_unique_keys | 5 |
#> | right_unique_keys | 5 |
#> | keys_matched | 3 |
#> | keys_left_only | 2 |
#> | keys_right_only | 2 |
#> | match_rate | 0.6 |
#> | issues | 0 |
#> | inner_join_rows | 3 |
#> | left_join_rows | 5 |
#> | right_join_rows | 5 |
#> | full_join_rows | 7 |
```
