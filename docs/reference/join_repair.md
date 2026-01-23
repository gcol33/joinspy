# Repair Common Key Issues

Automatically fixes trivial join key issues like whitespace and case
mismatches. Returns the repaired data frame(s) with a summary of
changes.

## Usage

``` r
join_repair(
  x,
  y = NULL,
  by,
  trim_whitespace = TRUE,
  standardize_case = NULL,
  remove_invisible = TRUE,
  empty_to_na = FALSE,
  dry_run = FALSE
)
```

## Arguments

- x:

  A data frame (left table).

- y:

  A data frame (right table). If NULL, only repairs x.

- by:

  A character vector of column names to repair.

- trim_whitespace:

  Logical. Trim leading/trailing whitespace. Default TRUE.

- standardize_case:

  Character. Standardize case to "lower", "upper", or NULL (no change).
  Default NULL.

- remove_invisible:

  Logical. Remove invisible Unicode characters. Default TRUE.

- empty_to_na:

  Logical. Convert empty strings to NA. Default FALSE.

- dry_run:

  Logical. If TRUE, only report what would be changed without modifying
  data. Default FALSE.

## Value

If `y` is NULL, returns the repaired `x`. If both are provided, returns
a list with `x` and `y`. In dry_run mode, returns a summary of proposed
changes.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)

## Examples

``` r
# Data with whitespace issues
orders <- data.frame(
  id = c(" A", "B ", "C"),
  value = 1:3,
  stringsAsFactors = FALSE
)

# Dry run to see what would change
join_repair(orders, by = "id", dry_run = TRUE)
#> 
#> ── Repair Preview (Dry Run) ────────────────────────────────────────────────────
#> 
#> ── Left table (x) ──
#> 
#> ℹ id: trimmed whitespace (2)

# Actually repair
orders_fixed <- join_repair(orders, by = "id")
#> ✔ Repaired 2 value(s)
```
