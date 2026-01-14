# Plot Venn Diagram of Key Overlap

Creates a simple Venn diagram showing the overlap between keys in two
tables.

## Usage

``` r
plot_venn(
  report,
  file = NULL,
  width = 6,
  height = 5,
  colors = c("#4A90D9", "#D94A4A")
)
```

## Arguments

- report:

  A `JoinReport` object from
  [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md).

- file:

  Optional file path to save the plot (PNG or SVG based on extension).
  If NULL, displays in the current graphics device.

- width:

  Width in inches (default 6).

- height:

  Height in inches (default 5).

- colors:

  Character vector of length 2 for left and right circle colors.

## Value

Invisibly returns the plot data.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`plot_summary()`](https://gillescolling.com/joinspy/reference/plot_summary.md)

## Examples

``` r
orders <- data.frame(id = 1:5, val = 1:5)
customers <- data.frame(id = 3:7, name = letters[3:7])

report <- join_spy(orders, customers, by = "id")
plot_venn(report)
```
