# Configure Automatic Logging

Sets up automatic logging of all join reports to a specified file. When
enabled, every `*_join_spy()` call will append its report to the log.

## Usage

``` r
set_log_file(file, format = c("text", "json"))
```

## Arguments

- file:

  File path for automatic logging. Set to `NULL` to disable.

- format:

  Log format: "text" (default) or "json".

## Value

Invisibly returns the previous log file setting.

## See also

[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md),
[`get_log_file()`](https://gillescolling.com/joinspy/reference/get_log_file.md)

## Examples

``` r
# Enable automatic logging to temp file
tmp <- tempfile(fileext = ".log")
old <- set_log_file(tmp)
#> ℹ Automatic logging enabled: C:\Users\GILLES~1\AppData\Local\Temp\RtmpA3Fi1l\file3ad816a8202f.log

# Disable logging and clean up
set_log_file(NULL)
#> ℹ Automatic logging disabled
unlink(tmp)
```
