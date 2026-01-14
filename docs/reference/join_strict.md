# Strict Join with Cardinality Enforcement

Performs a join operation that fails if the specified cardinality
constraint is violated. Use this to catch unexpected many-to-many
relationships early.

## Usage

``` r
join_strict(
  x,
  y,
  by,
  type = c("left", "right", "inner", "full"),
  expect = c("1:1", "1:m", "1:many", "m:1", "many:1", "m:m", "many:many"),
  ...
)
```

## Arguments

- x:

  A data frame (left table).

- y:

  A data frame (right table).

- by:

  A character vector of column names to join by.

- type:

  Character. The type of join to perform. One of `"left"` (default),
  `"right"`, `"inner"`, `"full"`.

- expect:

  Character. The expected cardinality relationship. One of:

  "1:1"

  :   Each key in x matches at most one key in y, and vice versa

  "1:m" or "1:many"

  :   Each key in x can match multiple keys in y, but each key in y
      matches at most one key in x

  "m:1" or "many:1"

  :   Each key in y can match multiple keys in x, but each key in x
      matches at most one key in y

  "m:m" or "many:many"

  :   No cardinality constraints (allows all relationships)

- ...:

  Additional arguments passed to the underlying join function.

## Value

The joined data frame if the cardinality constraint is satisfied. Throws
an error if the constraint is violated.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)

## Examples

``` r
orders <- data.frame(id = 1:3, product = c("A", "B", "C"))
customers <- data.frame(id = 1:3, name = c("Alice", "Bob", "Carol"))

# This succeeds (1:1 relationship)
join_strict(orders, customers, by = "id", expect = "1:1")
#>   id product  name
#> 1  1       A Alice
#> 2  2       B   Bob
#> 3  3       C Carol

# This would fail if customers had duplicate ids
if (FALSE) { # \dontrun{
customers_dup <- data.frame(id = c(1, 1, 2), name = c("A1", "A2", "B"))
join_strict(orders, customers_dup, by = "id", expect = "1:1")
# Error: Expected 1:1 relationship but found 1:many
} # }
```
