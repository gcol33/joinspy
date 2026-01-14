# Plot Join Summary Table

Creates a formatted summary table suitable for reports or presentations.

## Usage

``` r
plot_summary(report, format = c("text", "markdown", "data.frame"))
```

## Arguments

- report:

  A `JoinReport` object from
  [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md).

- format:

  Output format: "text" (default), "markdown", or "data.frame".

## Value

Formatted table (printed for text/markdown, returned for data.frame).

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`plot_venn()`](https://gillescolling.com/joinspy/reference/plot_venn.md)

## Examples

``` r
orders <- data.frame(id = 1:5, val = 1:5)
customers <- data.frame(id = 3:7, name = letters[3:7])

report <- join_spy(orders, customers, by = "id")
plot_summary(report, format = "markdown")
```
