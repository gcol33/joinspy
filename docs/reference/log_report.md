# Log Join Report to File

Writes a `JoinReport` object to a file for audit trails and
reproducibility. Supports plain text, JSON, and RDS formats.

## Usage

``` r
log_report(report, file, append = FALSE, timestamp = TRUE)
```

## Arguments

- report:

  A `JoinReport` object from
  [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
  or retrieved via
  [`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md).

- file:

  File path to write to. Extension determines format:

  - `.txt` or `.log`: Plain text (human-readable)

  - `.json`: JSON format (machine-readable)

  - `.rds`: R binary format (preserves all data)

- append:

  Logical. If `TRUE`, appends to existing file (text/log only). Default
  `FALSE`.

- timestamp:

  Logical. If `TRUE` (default), includes timestamp in output.

## Value

Invisibly returns the file path.

## See also

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md),
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)

## Examples

``` r
orders <- data.frame(id = 1:3, value = c(10, 20, 30))
customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))

report <- join_spy(orders, customers, by = "id")

# Log to temporary file
tmp <- tempfile(fileext = ".log")
log_report(report, tmp, append = TRUE)
#> ✔ Report logged to C:\Users\GILLES~1\AppData\Local\Temp\Rtmp6jWz1Q\filecab015bb2755.log
unlink(tmp)
```
