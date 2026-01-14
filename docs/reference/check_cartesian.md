# Detect Potential Cartesian Product

Warns if a join will produce a very large result due to many-to-many
relationships (Cartesian product explosion).

## Usage

``` r
check_cartesian(x, y, by, threshold = 10)
```

## Arguments

- x:

  A data frame (left table).

- y:

  A data frame (right table).

- by:

  Column names to join by.

- threshold:

  Warn if result will exceed this many times the larger input. Default
  10.

## Value

A list with explosion analysis.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)

## Examples

``` r
# Dangerous: both tables have duplicates
x <- data.frame(id = c(1, 1, 2, 2), val_x = 1:4)
y <- data.frame(id = c(1, 1, 2, 2), val_y = 1:4)

check_cartesian(x, y, by = "id")
```
