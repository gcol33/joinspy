# Summary Method for JoinReport

Returns a compact summary data frame of the join diagnostic report.

## Usage

``` r
# S3 method for class 'JoinReport'
summary(object, format = c("data.frame", "text", "markdown"), ...)
```

## Arguments

- object:

  A `JoinReport` object.

- format:

  Output format: "data.frame" (default), "text", or "markdown".

- ...:

  Additional arguments (ignored).

## Value

A data frame with key metrics (or printed output for text/markdown).

## Examples

``` r
orders <- data.frame(id = 1:5, val = 1:5)
customers <- data.frame(id = 3:7, name = letters[3:7])

report <- join_spy(orders, customers, by = "id")
summary(report)
summary(report, format = "markdown")
```
