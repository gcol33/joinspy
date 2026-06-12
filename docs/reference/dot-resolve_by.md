# Resolve a possibly-named `by` into left and right column names

Resolve a possibly-named `by` into left and right column names

## Usage

``` r
.resolve_by(by)
```

## Arguments

- by:

  Character vector of join columns, optionally named for joins where
  column names differ (e.g., `c(id = "customer_id")`).

## Value

A list with elements `x` (left columns) and `y` (right columns).
