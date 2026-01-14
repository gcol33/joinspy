# Quick Key Quality Check

A fast check of join key quality that returns a simple pass/fail status
with a brief summary. Use this for quick validation; use
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
for detailed diagnostics.

## Usage

``` r
key_check(x, y, by, warn = TRUE)
```

## Arguments

- x:

  A data frame (left table in the join).

- y:

  A data frame (right table in the join).

- by:

  A character vector of column names to join by.

- warn:

  Logical. If `TRUE` (default), prints warnings for detected issues. Set
  to `FALSE` for silent operation.

## Value

Invisibly returns a logical: `TRUE` if no issues detected, `FALSE`
otherwise. Also prints a brief status message unless `warn = FALSE`.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)

## Examples

``` r
orders <- data.frame(id = c(1, 2, 2, 3), value = 1:4)
customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))

# Quick check
key_check(orders, customers, by = "id")

# Silent check
is_ok <- key_check(orders, customers, by = "id", warn = FALSE)
```
