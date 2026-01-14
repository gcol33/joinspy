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
if (FALSE) { # \dontrun{
# Enable automatic logging
set_log_file("joins.log")

# All subsequent joins are logged
left_join_spy(orders, customers, by = "id")

# Disable logging
set_log_file(NULL)
} # }
```
