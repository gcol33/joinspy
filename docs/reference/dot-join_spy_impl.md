# Internal join wrapper helper

Internal join wrapper helper

## Usage

``` r
.join_spy_impl(x, y, by, type, verbose, .quiet = FALSE, backend = NULL, ...)
```

## Arguments

- x:

  Left data frame.

- y:

  Right data frame.

- by:

  Column names.

- type:

  Join type.

- verbose:

  Print output.

- .quiet:

  Suppress all output (overrides verbose).

- backend:

  Join backend: NULL (auto-detect), "base", "dplyr", or "data.table".

- ...:

  Additional args passed to the underlying join function.

## Value

Joined data frame with report attribute.
