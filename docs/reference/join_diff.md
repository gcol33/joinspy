# Compare Data Frame Before and After Join

Shows a side-by-side comparison of key statistics before and after a
join operation.

## Usage

``` r
join_diff(before, after, by = NULL)
```

## Arguments

- before:

  The original data frame (before joining).

- after:

  The result data frame (after joining).

- by:

  Optional. Column names to analyze for key statistics.

## Value

Invisibly returns a comparison summary. Prints a formatted comparison.

## See also

[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md),
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)

## Examples

``` r
before <- data.frame(id = 1:3, x = letters[1:3])
after <- data.frame(id = c(1, 2, 2, 3), x = c("a", "b", "b", "c"), y = 1:4
)

join_diff(before, after)
```
