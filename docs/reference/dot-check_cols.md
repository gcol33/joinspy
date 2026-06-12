# Check that columns exist in a data frame

Check that columns exist in a data frame

## Usage

``` r
.check_cols(df, cols, side = NULL, call = rlang::caller_env())
```

## Arguments

- df:

  Data frame to check.

- cols:

  Column names that must be present.

- side:

  Optional side label (`"x"` or `"y"`) for the error message.

- call:

  Environment to attribute the error to.

## Value

Invisibly, `cols`.
