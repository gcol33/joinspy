# Detect Encoding Issues in Keys

Checks for encoding inconsistencies and invisible Unicode characters.

## Usage

``` r
.detect_encoding_issues(x)
```

## Arguments

- x:

  A character vector to check.

## Value

A list with:

- has_issues:

  Logical indicating if encoding issues found

- mixed_encoding:

  Logical if multiple encodings detected

- invisible_chars:

  Indices of values with invisible Unicode

- affected_values:

  Values with encoding issues
