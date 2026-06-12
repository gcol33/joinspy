# Classify the cardinality relationship from per-side duplicate flags

Classify the cardinality relationship from per-side duplicate flags

## Usage

``` r
.classify_cardinality(x_has_dups, y_has_dups)
```

## Arguments

- x_has_dups:

  Logical: the left table has duplicate keys.

- y_has_dups:

  Logical: the right table has duplicate keys.

## Value

One of `"1:1"`, `"1:n"`, `"n:1"`, `"n:m"`.
