# Build a single key vector from one or more columns

For composite keys, components are pasted with a unit-separator. A row
is marked `NA` whenever any of its key components is `NA`, matching how
joins treat a missing key component as non-matching.

## Usage

``` r
.make_key(data, cols)
```

## Arguments

- data:

  Data frame.

- cols:

  Column name(s) forming the key.

## Value

A vector of keys, `NA` where any component is `NA`.
