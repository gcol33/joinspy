# Suggest Repair Code

Analyzes join issues and returns R code snippets to fix them.

## Usage

``` r
suggest_repairs(report)
```

## Arguments

- report:

  A `JoinReport` object from
  [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md).

## Value

Character vector of R code snippets to fix detected issues.

## See also

[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md),
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)

## Examples

``` r
orders <- data.frame(id = c("A ", "B"), val = 1:2, stringsAsFactors = FALSE)
customers <- data.frame(id = c("a", "b"), name = c("Alice", "Bob"), stringsAsFactors = FALSE)

report <- join_spy(orders, customers, by = "id")
suggest_repairs(report)
```
