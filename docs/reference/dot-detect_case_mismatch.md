# Detect Case Mismatches Between Keys

Finds keys that would match if case-insensitive but don't match
case-sensitive.

## Usage

``` r
.detect_case_mismatch(x, y)
```

## Arguments

- x:

  A character vector (keys from left table).

- y:

  A character vector (keys from right table).

## Value

A list with:

- has_issues:

  Logical indicating if case mismatches found

- mismatches:

  Data frame of key pairs that differ only by case
