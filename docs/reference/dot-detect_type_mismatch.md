# Detect Type Mismatches Between Key Columns

Checks if key columns have compatible types for joining.

## Usage

``` r
.detect_type_mismatch(x_col, y_col, x_name, y_name)
```

## Arguments

- x_col:

  Column from left table.

- y_col:

  Column from right table.

- x_name:

  Name of left column.

- y_name:

  Name of right column.

## Value

A list with type mismatch information.
