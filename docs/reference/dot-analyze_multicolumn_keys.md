# Analyze Multi-Column Key Breakdown

For composite keys, determines which column(s) cause mismatches.

## Usage

``` r
.analyze_multicolumn_keys(x, y, x_by, y_by)
```

## Arguments

- x:

  Data frame (left table).

- y:

  Data frame (right table).

- x_by:

  Column names in x.

- y_by:

  Column names in y.

## Value

A list with per-column match analysis.
