# Perform a join using the appropriate backend

Single dispatch point for all join operations. Auto-detects the backend
from input classes, or uses an explicit override.

## Usage

``` r
.perform_join(x, y, by, type, backend = NULL, ...)
```

## Arguments

- x:

  Left data frame.

- y:

  Right data frame.

- by:

  Column names (character vector, possibly named).

- type:

  Join type: "left", "right", "inner", or "full".

- backend:

  Character or NULL. If NULL (default), auto-detects from input class.
  Explicit values: "base", "dplyr", "data.table".

- ...:

  Additional arguments passed to the underlying join function.

## Value

The joined data frame, preserving the input class.
