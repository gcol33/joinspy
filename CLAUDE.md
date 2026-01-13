# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**joinspy** is an R package that provides diagnostic tools for data frame joins. It helps users understand and debug join operations by analyzing key columns before and after joins, detecting common issues (duplicates, mismatches, encoding problems), and explaining unexpected row count changes.

## Development Commands

### Build and Install
```r
# Load package for development
devtools::load_all()

# Install package locally
devtools::install()

# Regenerate documentation (after roxygen2 changes)
devtools::document()
```

### Testing
```r
# Run full test suite
devtools::test()

# Run complete package check (includes tests, examples, documentation)
devtools::check()

# Run specific test file during development
testthat::test_file("tests/testthat/test-join_spy.R")
```

### Documentation
```r
# Build vignettes
devtools::build_vignettes()

# Build pkgdown site locally (output in docs/)
pkgdown::build_site()
```

## Architecture

### High-Level Design

The package provides diagnostic functions organized into three categories:

1. **Pre-join diagnostics** - Analyze tables before joining
   - `join_spy()` - Comprehensive pre-flight report
   - `key_check()` - Quick key quality assessment
   - `key_duplicates()` - Find duplicate keys

2. **Post-join diagnostics** - Understand what happened after a join
   - `join_explain()` - Explain row count changes
   - `join_diff()` - Compare before/after states

3. **Safe join wrappers** - Joins with built-in diagnostics
   - `left_join_spy()` - left_join with automatic reporting
   - `join_strict()` - Fails if cardinality constraints violated

### Core Data Structures

**JoinReport S3 class** - Returned by `join_spy()` and related functions:
- `x_summary` - Summary of left table keys
- `y_summary` - Summary of right table keys
- `match_analysis` - What will/won't match
- `issues` - Detected problems (duplicates, whitespace, encoding, case)
- `expected_rows` - Predicted row counts for each join type

### Key Detection Logic

The package detects these common issues:
1. **Duplicate keys** - Keys appearing multiple times (causes row multiplication)
2. **Trailing/leading whitespace** - Invisible characters breaking matches
3. **Case mismatches** - "ABC" vs "abc" that won't match
4. **Encoding issues** - UTF-8 vs Latin-1, invisible Unicode characters
5. **NA keys** - Missing values in join columns

## File Organization

```
R/                           # R source files
├── join_spy.R              # Main diagnostic function
├── key_check.R             # Key quality assessment
├── key_duplicates.R        # Duplicate detection
├── join_explain.R          # Post-join explanation
├── join_diff.R             # Before/after comparison
├── join_strict.R           # Cardinality-enforcing joins
├── join_wrappers.R         # *_join_spy() convenience functions
├── JoinReport.R            # S3 class definition and print method
├── string_diagnostics.R    # Encoding/whitespace detection utilities
└── joinspy-package.R       # Package-level documentation

tests/testthat/             # Unit tests
├── test-join_spy.R
├── test-key_check.R
├── test-join_explain.R
├── test-join_strict.R
└── test-string_diagnostics.R

vignettes/                   # Long-form documentation
├── introduction.Rmd        # Getting started guide
└── common-issues.Rmd       # Catalogue of join problems and solutions

man/                         # Generated documentation (roxygen2)
docs/                        # Generated pkgdown website
```

## Important Conventions

### Function Naming
- Diagnostic functions: `join_*` or `key_*` prefix
- Safe wrappers: `*_join_spy` suffix (e.g., `left_join_spy`)
- Internal helpers: `.` prefix (e.g., `.detect_whitespace`)

### Parameter Naming
Follow dplyr conventions:
- `x`, `y` for data frames (not `df1`, `df2`)
- `by` for join columns (character vector or named vector)
- Use snake_case throughout

### Return Values
- Diagnostic functions return `JoinReport` S3 objects with custom `print()` method
- Safe wrappers return the joined data frame with report as attribute
- Use `invisible()` for side-effect functions

### Error Handling
- Use `stop(..., call. = FALSE)` for user-facing errors
- Use `warning()` for recoverable issues
- Use `message()` for informational output (can be suppressed)

## Testing Guidelines

- Use `set.seed()` for any randomized test data
- Test edge cases: empty data frames, single row, all duplicates, no matches
- Test encoding issues with explicit UTF-8 strings
- Test both character and named vector `by` specifications
- Include tests for tibbles, data.tables, and base data.frames

## Documentation

All exported functions use roxygen2 documentation with:
- `@param` descriptions matching dplyr style
- `@return` describing the `JoinReport` structure
- `@details` explaining what issues are detected
- `@examples` using built-in datasets (mtcars, iris) or small synthetic data
- `@seealso` linking related functions

## Dependencies

Keep dependencies minimal:
- **Imports**: rlang (for tidy evaluation if needed), cli (for pretty printing)
- **Suggests**: dplyr, data.table, tibble, testthat, knitr, rmarkdown

The package should work with base R joins (`merge()`) and dplyr joins.
