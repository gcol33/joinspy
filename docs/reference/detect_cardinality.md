# Detect Join Relationship Type

Determines the actual cardinality relationship between two tables.

## Usage

``` r
detect_cardinality(x, y, by)
```

## Arguments

- x:

  A data frame (left table).

- y:

  A data frame (right table).

- by:

  Column names to join by.

## Value

Character string: "1:1", "1:m", "m:1", or "m:m".

## See also

[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md),
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)

## Examples

``` r
# 1:1 relationship
x <- data.frame(id = 1:3, val = 1:3)
y <- data.frame(id = 1:3, name = c("A", "B", "C"))
detect_cardinality(x, y, "id")
#> ℹ Detected cardinality: "1:1"

# 1:m relationship
x <- data.frame(id = 1:3, val = 1:3)
y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))
detect_cardinality(x, y, "id")
#> ℹ Detected cardinality: "1:m"
#> Right duplicates: 1 key(s)
```
