# Plot Method for JoinReport

Creates a Venn diagram showing key overlap between tables.

## Usage

``` r
# S3 method for class 'JoinReport'
plot(x, type = c("venn"), ...)
```

## Arguments

- x:

  A `JoinReport` object.

- type:

  Type of plot: `"venn"` (default) for Venn diagram.

- ...:

  Additional arguments passed to
  [`plot_venn()`](https://gillescolling.com/joinspy/reference/plot_venn.md).

## Value

Invisibly returns the plot data.

## See also

[`plot_venn()`](https://gillescolling.com/joinspy/reference/plot_venn.md),
[`plot_summary()`](https://gillescolling.com/joinspy/reference/plot_summary.md)

## Examples

``` r
orders <- data.frame(id = 1:5, val = 1:5)
customers <- data.frame(id = 3:7, name = letters[3:7])

report <- join_spy(orders, customers, by = "id")
plot(report)
```
