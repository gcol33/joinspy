# joinspy <img src="man/figures/logo.png" align="right" height="139" alt="" />
<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/gcol33/joinspy/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/gcol33/joinspy/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/joinspy)](https://CRAN.R-project.org/package=joinspy)
<!-- badges: end -->

**joinspy** provides diagnostic tools for data frame joins in R. It helps you understand and debug join operations by analyzing key columns before and after joins, detecting common issues, and explaining unexpected row count changes.

## The Problem

Joins silently produce unexpected results when:

- **Duplicate keys** cause row multiplication
- **Trailing whitespace** breaks matches invisibly
- **Case mismatches** ("ABC" vs "abc") prevent joins
- **Encoding issues** make identical-looking strings different
- **NA values** in keys cause unexpected behavior

You only discover these problems when downstream analysis breaks. joinspy catches them early.

## Installation

```r
# Install from CRAN (when available)
install.packages("joinspy")
# Install development version from GitHub
# install.packages("pak")
pak::pak("gcol33/joinspy")
```

## Quick Start

### Pre-flight diagnostics

Before joining, run `join_spy()` to see what will happen:
```r
library(joinspy)

join_spy(orders, customers, by = "customer_id")
#> JOIN DIAGNOSTIC REPORT
#> ──────────────────────
#> Key column: customer_id
#>
#> Left table (orders):
#>   Rows: 1,234 | Unique keys: 1,100 | Duplicates: 134
#>

#> Right table (customers):
#>   Rows: 1,000 | Unique keys: 1,000 | Duplicates: 0
#>
#> Match analysis:
#>   Will match:     1,050 rows (85%)
#>   Won't match:    184 rows (orphaned)
#>
#> ⚠ Issues detected:
#>   • 23 keys have trailing whitespace
#>   • 5 keys differ only by case
#>
#> Expected row counts:
#>   left_join:  1,180 rows
#>   inner_join: 1,050 rows
#>   full_join:  1,234 rows
```

### Quick key check

For a fast summary without full diagnostics:

```r
key_check(orders, customers, by = "customer_id")
#> ✓ Keys look good: 95% match rate, no duplicates in right table
```
### Post-join explanation

Understand what happened after a join:

```r
result <- left_join(orders, customers, by = "customer_id")
join_explain(result, orders, customers, by = "customer_id
")
#> Row count: 1,234 → 1,380 (+146 rows)
#> Cause: 47 duplicate keys in 'customers' expanded matching rows
```

### Safe joins

Use strict joins to enforce cardinality:

```r
# Fails if join would create duplicate rows
join_strict(orders, customers, by = "customer_id", expect = "1:1")
#> Error: Expected 1:1 relationship but found 1:many
#>        47 keys in 'customers' have duplicates
```

## Core Functions
| Function | Purpose |
|----------|---------|
| `join_spy()` | Comprehensive pre-join diagnostic report |
| `key_check()` | Quick key quality assessment |
| `key_duplicates()` | Find and locate duplicate keys |
| `join_explain()` | Explain row count changes post-join |
| `join_strict()` | Join with cardinality enforcement |
| `left_join_spy()` | left_join with automatic diagnostics |

## Common Issues Detected

- **Duplicate keys**: Keys appearing multiple times (causes Cartesian explosion)
- **Whitespace**: Leading/trailing spaces that break exact matches
- **Case sensitivity**: "ABC" vs "abc" mismatches
- **Encoding**: UTF-8 vs Latin-1, invisible Unicode characters
- **NA keys**: Missing values in join columns
- **Type mismatches**: Character "1" vs numeric 1

## Learn More

- [Getting Started vignette](https://gillescolling.com/joinspy/articles/introduction.html)
- [Common Join Issues](https://gillescolling.com/joinspy/articles/common-issues.html)
- [Function reference](https://gillescolling.com/joinspy/reference/index.html)

## Related Work
- [dplyr](https://dplyr.tidyverse.org/) - The `relationship` argument provides basic cardinality checks
- [tidylog](https://github.com/elbersb/tidylog) - Logs row count changes (but doesn't diagnose causes)

joinspy fills the gap: it tells you **why** joins misbehave and **where** the problems are.

## License

MIT
