# joinspy Roadmap

## Phase 1: Core Implementation (v0.1.0) ✅ COMPLETE

### Infrastructure

`JoinReport` S3 class and print method

`string_diagnostics.R` utilities (whitespace, encoding, case detection)

NAMESPACE generation via roxygen2

### Core Functions

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) -
Comprehensive pre-join diagnostic report

[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md) -
Quick key quality assessment

[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md) -
Find and locate duplicate keys

[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md) -
Explain row count changes post-join

[`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md) -
Before/after state comparison

[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md) -
Join with cardinality enforcement

### Join Wrappers

[`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)

[`right_join_spy()`](https://gillescolling.com/joinspy/reference/right_join_spy.md)

[`inner_join_spy()`](https://gillescolling.com/joinspy/reference/inner_join_spy.md)

[`full_join_spy()`](https://gillescolling.com/joinspy/reference/full_join_spy.md)

### Issue Detection (v0.1.0)

Duplicate key detection with row locations

Whitespace detection (leading/trailing spaces)

Case mismatch detection

Encoding issue detection (UTF-8 vs Latin-1, invisible Unicode)

NA key detection

Cardinality analysis (1:1, 1:many, many:1, many:many)

### Tests & Documentation

Comprehensive test suite for all functions (117 tests)

`introduction.Rmd` vignette

`common-issues.Rmd` vignette

------------------------------------------------------------------------

## Phase 2: Enhanced Detection (v0.2.0) ✅ COMPLETE

### Type & Format Issues

Type coercion warnings (character to factor, numeric-as-string to
numeric)

Factor level mismatches between tables

Empty string vs NA distinction (behave differently in joins)

Numeric precision warnings for floating-point keys

### Near-Match Detection

Fuzzy match candidates (Levenshtein distance ≤ 2)

Suggest potential matches for unmatched keys

Configurable similarity threshold

### Multi-Column Join Analysis

Per-column breakdown for composite keys (which column causes mismatch)

Problem column identification (lowest match rate)

------------------------------------------------------------------------

## Phase 3: Auto-Fix & Repair (v0.3.0) ✅ COMPLETE

### Repair Functions

[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md) -
Automatically fix trivial issues

- Trim whitespace
- Standardize case (to lower/upper)
- Remove invisible characters
- Convert empty strings to NA

[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md) -
Return code snippets to fix detected issues

Dry-run mode - Show what would be fixed without modifying

------------------------------------------------------------------------

## Phase 4: Performance & Scale (v0.4.0) ✅ COMPLETE

### Large Dataset Support

Sampling mode: `join_spy(x, y, by, sample = 10000)`

Memory estimation for join result

Reproducible sampling with seed

------------------------------------------------------------------------

## Phase 5: Visualization (v0.5.0) ✅ COMPLETE

### Diagrams

[`plot_venn()`](https://gillescolling.com/joinspy/reference/plot_venn.md) -
Venn diagram of key overlap (PNG/SVG/PDF export)

[`plot_summary()`](https://gillescolling.com/joinspy/reference/plot_summary.md) -
Summary tables (text/markdown/data.frame)

------------------------------------------------------------------------

## Phase 6: Advanced Join Patterns (v0.6.0) ✅ COMPLETE

### Specialized Joins

[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md) -
Cross-join/Cartesian product warnings

[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md) -
Determine actual cardinality relationship

### Multi-Table Analysis

[`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md) -
Cascading join analysis for multi-table chains

------------------------------------------------------------------------

## Phase 7: Integration (v0.7.0) ✅ COMPLETE

### IDE Integration

RStudio addin for interactive exploration (`addin_join_inspector`)

Shiny gadget with table/column selection

### Logging & Audit

[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md) -
Write reports to file (text/JSON/RDS)

[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
/
[`get_log_file()`](https://gillescolling.com/joinspy/reference/get_log_file.md) -
Automatic logging configuration

### Pipe-Friendly Enhancements

Silent mode: `x %>% left_join_spy(y, by, .quiet = TRUE)`

[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md) -
Deferred report access

------------------------------------------------------------------------

## Summary

| Phase                  | Status         | Tests   | Functions         |
|------------------------|----------------|---------|-------------------|
| 1 - Core               | ✅ Complete    | 117     | 11                |
| 2 - Enhanced Detection | ✅ Complete    | +18     | +7 internal       |
| 3 - Auto-Fix           | ✅ Complete    | +5      | 2                 |
| 4 - Performance        | ✅ Complete    | +2      | sampling + memory |
| 5 - Visualization      | ✅ Complete    | +2      | 2                 |
| 6 - Advanced           | ✅ Complete    | +6      | 3                 |
| 7 - Integration        | ✅ Complete    | +0      | 4                 |
| **Total**              | **7/7 phases** | **159** | **22 exported**   |
