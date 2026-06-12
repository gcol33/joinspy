# Validate that an object is a data frame

Validate that an object is a data frame

## Usage

``` r
.validate_df(x, arg, call = rlang::caller_env())
```

## Arguments

- x:

  Object to check.

- arg:

  Argument name used in the error message.

- call:

  Environment to attribute the error to.

## Value

Invisibly, `x`.
