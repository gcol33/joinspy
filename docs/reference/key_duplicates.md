# Find Duplicate Keys

Identifies rows with duplicate values in the specified key columns.
Returns a data frame containing only the rows with duplicated keys,
along with a count of occurrences.

## Usage

``` r
key_duplicates(data, by, keep = c("all", "first", "last"))
```

## Arguments

- data:

  A data frame.

- by:

  A character vector of column names to check for duplicates.

- keep:

  Character. Which duplicates to return:

  "all"

  :   Return all rows with duplicated keys (default)

  "first"

  :   Return only the first occurrence of each duplicate

  "last"

  :   Return only the last occurrence of each duplicate

## Value

A data frame containing the duplicated rows, with an additional column
`.n_duplicates` showing how many times each key appears. Returns an
empty data frame (0 rows) if no duplicates found.

## See also

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md),
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)

## Examples

``` r
df <- data.frame(
  id = c(1, 2, 2, 3, 3, 3, 4),
  value = letters[1:7]
)

# Find all duplicates
key_duplicates(df, by = "id")
#>   id value .n_duplicates
#> 2  2     b             2
#> 3  2     c             2
#> 4  3     d             3
#> 5  3     e             3
#> 6  3     f             3

# Find first occurrence only
key_duplicates(df, by = "id", keep = "first")
#>   id value .n_duplicates
#> 2  2     b             2
#> 4  3     d             3
```
