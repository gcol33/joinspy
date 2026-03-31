# joinspy

[![CRAN status](https://www.r-pkg.org/badges/version/joinspy)](https://CRAN.R-project.org/package=joinspy)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/joinspy)](https://cran.r-project.org/package=joinspy)
[![Monthly downloads](https://cranlogs.r-pkg.org/badges/joinspy)](https://cran.r-project.org/package=joinspy)
[![R-CMD-check](https://github.com/gcol33/joinspy/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/gcol33/joinspy/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/gcol33/joinspy/graph/badge.svg)](https://app.codecov.io/gh/gcol33/joinspy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Find out why your keys don't match.**

You ran a left join and lost 40% of your rows. dplyr says "many-to-many relationship." joinspy says 12 keys have trailing spaces, 8 differ only by case, and 3 contain invisible Unicode characters. Then it fixes them.

## Quick Start

```r
library(joinspy)

join_spy(orders, customers, by = "customer_id")

repaired <- join_repair(orders, customers, by = "customer_id")

suggest_repairs(join_spy(orders, customers, by = "customer_id"))
```

## The Problem

Most join failures come down to string-level problems in keys:

- `"Alice"` vs `"Alice "` (trailing space, invisible)
- `"NYC"` vs `"nyc"` (case)
- Zero-width spaces, BOMs, non-breaking spaces that look like regular spaces but aren't
- `"Johansson"` vs `"Johannson"` (one character off)
- Empty strings matching each other but not `NA`

R won't warn you about any of these. `join_spy()` catches them before the join runs.

## What joinspy Does

### Diagnose

`join_spy()` examines keys before the join:

```r
orders <- data.frame(
  id = c("A", "B ", "c", "D"),
  amount = c(100, 200, 300, 400),
  stringsAsFactors = FALSE
)

customers <- data.frame(
  id = c("A", "B", "C", "E"),
  name = c("Alice", "Bob", "Carol", "Eve"),
  stringsAsFactors = FALSE
)

join_spy(orders, customers, by = "id")
#> -- Join Diagnostic Report --
#> Match rate (left): 25%
#>
#> Issues Detected:
#>   ! "B " has trailing whitespace (would match "B")
#>   ! "c" vs "C" — case mismatch
#>   x "D" has no match in right table
```

### Repair

`join_repair()` fixes the issues, or previews what it would change with `dry_run = TRUE`. `suggest_repairs()` prints the R code instead of running it.

```r
join_repair(orders, customers, by = "id", dry_run = TRUE)

repaired <- join_repair(orders, customers, by = "id",
                        standardize_case = "upper")

suggest_repairs(join_spy(orders, customers, by = "id"))
#> x$id <- trimws(x$id)
#> x$id <- toupper(x$id)
#> y$id <- toupper(y$id)
```

### Predict

`join_spy()` also estimates result size for each join type:

```r
report <- join_spy(orders, customers, by = "id")
report$expected_rows
#> inner_join: 1
#> left_join:  4
#> right_join: 4
#> full_join:  7
```

### Explain

`join_explain()` works after the join, on the result:

```r
result <- merge(orders, customers, by = "id", all.x = TRUE)
join_explain(result, orders, customers, by = "id", type = "left")
#> Result has same row count as left table
#> ! 3 left key(s) have no match in right table
```

## Also Includes

The package ships join wrappers (`left_join_spy()`, `inner_join_spy()`, etc.) that run diagnostics before joining and attach the report as an attribute. `join_strict()` enforces cardinality (`1:1`, `1:m`, `m:1`, `m:m`) and errors on violation. `check_cartesian()` warns before a many-to-many blows up your row count. `analyze_join_chain()` handles multi-step A-B-C sequences.

Joins auto-detect the input class (tibble, data.table, data.frame) and dispatch to the native join engine. Override with `backend = "dplyr"` or `backend = "data.table"` if needed.

## Installation

```r
# Install from CRAN
install.packages("joinspy")

# Or install development version from GitHub
# install.packages("pak")
pak::pak("gcol33/joinspy")
```

## Documentation

- [Getting Started](https://gillescolling.com/joinspy/articles/quickstart.html)
- [Why Your Keys Don't Match](https://gillescolling.com/joinspy/articles/why-keys-dont-match.html)
- [Common Join Issues](https://gillescolling.com/joinspy/articles/common-issues.html)
- [Joins in Production](https://gillescolling.com/joinspy/articles/production.html)
- [Working with Backends](https://gillescolling.com/joinspy/articles/backends.html)
- [Function Reference](https://gillescolling.com/joinspy/reference/index.html)

## Related Work

| Package | Focus |
|---------|-------|
| [dplyr](https://dplyr.tidyverse.org/) 1.1+ | Cardinality checks via `relationship` argument |
| [powerjoin](https://github.com/moodymudskipper/powerjoin) | 12-level configurable checks, key preprocessing |
| [joyn](https://github.com/randrescastaneda/joyn) | Match-status reporting variable per row |
| [tidylog](https://github.com/elbersb/tidylog) | Logs row count changes after joins |

joinspy focuses on string-level key diagnostics: whitespace, case, encoding, typos, and type mismatches. It identifies which specific keys failed, why, and can fix them automatically.

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
