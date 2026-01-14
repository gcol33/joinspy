# Detect Whitespace Issues in Keys

Checks for leading or trailing whitespace in character vectors.

## Usage

``` r
.detect_whitespace(x)
```

## Arguments

- x:

  A character vector to check.

## Value

A list with:

- has_issues:

  Logical indicating if whitespace issues found

- leading:

  Indices of values with leading whitespace

- trailing:

  Indices of values with trailing whitespace

- affected_values:

  Unique values with whitespace issues
