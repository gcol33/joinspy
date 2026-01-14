# Changelog

## joinspy 0.7.0

### Integration & Workflow

- **RStudio addin**:
  [`addin_join_inspector()`](https://gillescolling.com/joinspy/reference/addin_join_inspector.md)
  opens an interactive Shiny gadget for exploring join diagnostics
- **Logging & audit**:
  [`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
  writes reports to file (text/JSON/RDS format)
- **Automatic logging**:
  [`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
  /
  [`get_log_file()`](https://gillescolling.com/joinspy/reference/get_log_file.md)
  for session-wide logging configuration
- **Deferred access**:
  [`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
  retrieves diagnostics after silent joins
- **Silent mode**: `.quiet = TRUE` parameter for all `*_join_spy()`
  wrappers

------------------------------------------------------------------------

## joinspy 0.6.0

### Advanced Join Patterns

- **[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)**:
  Detect and warn about cross-join / Cartesian product explosions
- **[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)**:
  Determine actual key relationship (1:1, 1:m, m:1, m:m)
- **[`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md)**:
  Analyze cascading joins in multi-table workflows

------------------------------------------------------------------------

## joinspy 0.5.0

### Visualization

- **[`plot_venn()`](https://gillescolling.com/joinspy/reference/plot_venn.md)**:
  Venn diagram of key overlap with PNG/SVG/PDF export
- **[`plot_summary()`](https://gillescolling.com/joinspy/reference/plot_summary.md)**:
  Summary tables in text, markdown, or data.frame format
- **S3 integration**:
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method for
  JoinReport objects

------------------------------------------------------------------------

## joinspy 0.4.0

### Performance & Scale

- **Sampling mode**: `join_spy(x, y, by, sample = 10000)` for large
  datasets
- **Memory estimation**: Predict join result size before execution
- **Reproducible sampling**: Optional `seed` parameter for consistent
  results

------------------------------------------------------------------------

## joinspy 0.3.0

### Auto-Repair

- **[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)**:
  Automatically fix common key issues
  - Trim leading/trailing whitespace
  - Standardize case (to lower/upper)
  - Remove invisible characters
  - Convert empty strings to NA
- **[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)**:
  Generate R code snippets to fix detected issues
- **Dry-run mode**: Preview changes without modifying data

------------------------------------------------------------------------

## joinspy 0.2.0

### Enhanced Detection

#### Type & Format Issues

- Type coercion warnings (character to factor, numeric-as-string to
  numeric)
- Factor level mismatches between tables
- Empty string vs NA distinction
- Numeric precision warnings for floating-point keys

#### Near-Match Detection

- Fuzzy match candidates (Levenshtein distance ≤ 2)
- Suggested matches for unmatched keys
- Configurable similarity threshold

#### Multi-Column Join Analysis

- Per-column breakdown for composite keys
- Problem column identification (lowest match rate)

------------------------------------------------------------------------

## joinspy 0.1.0

Initial release.

### Core Functions

- [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) -
  Comprehensive pre-join diagnostic report
- [`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md) -
  Quick key quality assessment
- [`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md) -
  Find and locate duplicate keys
- [`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md) -
  Explain row count changes post-join
- [`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md) -
  Before/after state comparison
- [`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md) -
  Join with cardinality enforcement
- [`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md),
  [`right_join_spy()`](https://gillescolling.com/joinspy/reference/right_join_spy.md),
  [`inner_join_spy()`](https://gillescolling.com/joinspy/reference/inner_join_spy.md),
  [`full_join_spy()`](https://gillescolling.com/joinspy/reference/full_join_spy.md) -
  Join wrappers with diagnostics

### Issue Detection

- Duplicate key detection with row locations
- Whitespace detection (leading/trailing spaces)
- Case mismatch detection
- Encoding issue detection (UTF-8 vs Latin-1, invisible Unicode)
- NA key detection
- Cardinality analysis (1:1, 1:many, many:1, many:many)

### S3 Methods

- [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods for
  JoinReport objects

### Documentation

- Getting started vignette
- Common issues troubleshooting guide
