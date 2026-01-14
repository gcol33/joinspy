# joinspy

[![CRAN status](https://www.r-pkg.org/badges/version/joinspy)](https://CRAN.R-project.org/package=joinspy)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/joinspy)](https://cran.r-project.org/package=joinspy)
[![Monthly downloads](https://cranlogs.r-pkg.org/badges/joinspy)](https://cran.r-project.org/package=joinspy)
[![R-CMD-check](https://github.com/gcol33/joinspy/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/gcol33/joinspy/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/gcol33/joinspy/graph/badge.svg)](https://app.codecov.io/gh/gcol33/joinspy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Diagnostic Tools for Data Frame Joins in R**

The `joinspy` package helps you understand and debug join operations by analyzing key columns before and after joins, detecting common issues, and explaining unexpected row count changes. Catch problems early instead of discovering them when downstream analysis breaks.

## Quick Start

```r
library(joinspy)

# Pre-join diagnostics
report <- join_spy(orders, customers, by = "customer_id")
summary(report)

# Quick pass/fail check
key_check(orders, customers, by = "customer_id")

# Safe join with cardinality enforcement
result <- join_strict(orders, customers, by = "customer_id", expect = "1:1")

# Auto-repair common issues
orders_fixed <- join_repair(orders, by = "customer_id")
```

## Statement of Need

Joins silently produce unexpected results when:

- **Duplicate keys** cause row multiplication
- **Trailing whitespace** breaks matches invisibly
- **Case mismatches** ("ABC" vs "abc") prevent joins
- **Encoding issues** make identical-looking strings different
- **NA values** in keys cause unexpected behavior
- **Type mismatches** (character "1" vs numeric 1) fail silently

These problems are discovered only when downstream analysis breaks. `joinspy` catches them upfront by analyzing keys **before** you join, explaining **why** joins misbehave, and showing **where** the problems are.

## Features

### Pre-Join Diagnostics

- **`join_spy()`**: Comprehensive pre-flight diagnostic report
- **`key_check()`**: Quick pass/fail key quality assessment
- **`key_duplicates()`**: Find and locate duplicate keys

### Post-Join Analysis

- **`join_explain()`**: Explain row count changes after a join
- **`join_diff()`**: Compare before/after states

### Safe Join Wrappers

- **`join_strict()`**: Join with cardinality enforcement (`1:1`, `1:m`, `m:1`, `m:m`)
- **`left_join_spy()`**, **`right_join_spy()`**, **`inner_join_spy()`**, **`full_join_spy()`**: Joins with automatic diagnostics
- **`last_report()`**: Retrieve diagnostics after silent (`.quiet = TRUE`) joins

### Auto-Repair

- **`join_repair()`**: Fix whitespace, case, encoding, empty strings automatically
- **`suggest_repairs()`**: Generate R code snippets to fix detected issues

### Advanced Analysis

- **`detect_cardinality()`**: Determine actual relationship (1:1, 1:m, m:1, m:m)
- **`check_cartesian()`**: Warn about Cartesian product explosions
- **`analyze_join_chain()`**: Analyze multi-table join sequences

### Visualization & Logging

- **`plot()`**: Venn diagram of key overlap (with optional `file` param to save)
- **`summary()`**: Compact metrics table (with optional `format` param for text/markdown)
- **`log_report()`**: Write reports to file (text/JSON/RDS)
- **`set_log_file()`**: Enable automatic logging

## Installation

```r
# Install from CRAN (when available)
install.packages("joinspy")

# Or install development version from GitHub
# install.packages("pak")
pak::pak("gcol33/joinspy")
```

## Usage Examples

### Pre-Join Diagnostics

```r
library(joinspy)

orders <- data.frame(
  customer_id = c("A", "B", "B", "C", "D "),
  amount = c(100, 200, 150, 300, 50),
  stringsAsFactors = FALSE
)

customers <- data.frame(
  customer_id = c("A", "B", "C", "D", "E"),
  name = c("Alice", "Bob", "Carol", "David", "Eve"),
  stringsAsFactors = FALSE
)

# Full diagnostic report
report <- join_spy(orders, customers, by = "customer_id")

# Compact summary
summary(report)
#>              metric value
#> 1         left_rows     5
#> 2        right_rows     5
#> 3   left_unique_keys    4
#> 4  right_unique_keys    5
#> ...
```

### Cardinality Enforcement

```r
# Succeeds - 1:1 relationship
products <- data.frame(id = 1:3, name = c("Widget", "Gadget", "Gizmo"))
prices <- data.frame(id = 1:3, price = c(10, 20, 30))

join_strict(products, prices, by = "id", expect = "1:1")

# Fails - duplicates violate 1:1
prices_dup <- data.frame(id = c(1, 1, 2, 3), price = c(10, 15, 20, 30))
join_strict(products, prices_dup, by = "id", expect = "1:1")
#> Error: Cardinality violation: expected '1:1' but found '1:m'
```

### Auto-Repair

```r
messy <- data.frame(
  id = c(" A", "B ", "  C  "),
  value = 1:3,
  stringsAsFactors = FALSE
)

# Preview what would be fixed
join_repair(messy, by = "id", dry_run = TRUE)

# Apply fixes
fixed <- join_repair(messy, by = "id")
fixed$id
#> [1] "A" "B" "C"
```

### Silent Pipeline Mode

```r
# Silent join for pipelines
result <- left_join_spy(orders, customers, by = "customer_id", .quiet = TRUE)

# Access diagnostics afterward
last_report()$match_analysis$match_rate
#> [1] 0.8
```

### Visualization

```r
report <- join_spy(orders, customers, by = "customer_id")

# Venn diagram
plot(report)

# Save to file
plot(report, file = "overlap.png")
```

## Documentation

- [Getting Started](https://gillescolling.com/joinspy/articles/introduction.html)
- [Common Join Issues](https://gillescolling.com/joinspy/articles/common-issues.html)
- [Function Reference](https://gillescolling.com/joinspy/reference/index.html)

## Related Work

- [dplyr](https://dplyr.tidyverse.org/) - The `relationship` argument provides basic cardinality checks
- [tidylog](https://github.com/elbersb/tidylog) - Logs row count changes (but doesn't diagnose causes)

`joinspy` fills the gap: it tells you **why** joins misbehave and **where** the problems are.

## Support

> "Software is like sex: it's better when it's free." — Linus Torvalds

I'm a PhD student who builds R packages in my free time because I believe good tools should be free and open. I started these projects for my own work and figured others might find them useful too.

If this package saved you some time, buying me a coffee is a nice way to say thanks.

[![Buy Me A Coffee](https://img.shields.io/badge/-Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/gcol33)

## License

MIT (see the LICENSE.md file)

## Citation

```bibtex
@software{joinspy,
  author = {Colling, Gilles},
  title = {joinspy: Diagnostic Tools for Data Frame Joins},
  year = {2025},
  url = {https://github.com/gcol33/joinspy}
}
```
