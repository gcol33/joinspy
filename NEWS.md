# joinspy 0.7.0

## Integration & Workflow

- **RStudio addin**: `addin_join_inspector()` opens an interactive Shiny gadget for exploring join diagnostics
- **Logging & audit**: `log_report()` writes reports to file (text/JSON/RDS format)
- **Automatic logging**: `set_log_file()` / `get_log_file()` for session-wide logging configuration
- **Deferred access**: `last_report()` retrieves diagnostics after silent joins
- **Silent mode**: `.quiet = TRUE` parameter for all `*_join_spy()` wrappers

---

# joinspy 0.6.0

## Advanced Join Patterns

- **`check_cartesian()`**: Detect and warn about cross-join / Cartesian product explosions
- **`detect_cardinality()`**: Determine actual key relationship (1:1, 1:m, m:1, m:m)
- **`analyze_join_chain()`**: Analyze cascading joins in multi-table workflows

---

# joinspy 0.5.0

## Visualization

- **`plot_venn()`**: Venn diagram of key overlap with PNG/SVG/PDF export
- **`plot_summary()`**: Summary tables in text, markdown, or data.frame format
- **S3 integration**: `plot()` method for JoinReport objects

---

# joinspy 0.4.0

## Performance & Scale

- **Sampling mode**: `join_spy(x, y, by, sample = 10000)` for large datasets
- **Memory estimation**: Predict join result size before execution
- **Reproducible sampling**: Optional `seed` parameter for consistent results

---

# joinspy 0.3.0

## Auto-Repair

- **`join_repair()`**: Automatically fix common key issues
  - Trim leading/trailing whitespace
  - Standardize case (to lower/upper)
  - Remove invisible characters
  - Convert empty strings to NA
- **`suggest_repairs()`**: Generate R code snippets to fix detected issues
- **Dry-run mode**: Preview changes without modifying data

---

# joinspy 0.2.0

## Enhanced Detection

### Type & Format Issues

- Type coercion warnings (character to factor, numeric-as-string to numeric)
- Factor level mismatches between tables
- Empty string vs NA distinction
- Numeric precision warnings for floating-point keys

### Near-Match Detection

- Fuzzy match candidates (Levenshtein distance ≤ 2)
- Suggested matches for unmatched keys
- Configurable similarity threshold

### Multi-Column Join Analysis

- Per-column breakdown for composite keys
- Problem column identification (lowest match rate)

---

# joinspy 0.1.0

Initial release.

## Core Functions

- `join_spy()` - Comprehensive pre-join diagnostic report
- `key_check()` - Quick key quality assessment
- `key_duplicates()` - Find and locate duplicate keys
- `join_explain()` - Explain row count changes post-join
- `join_diff()` - Before/after state comparison
- `join_strict()` - Join with cardinality enforcement
- `left_join_spy()`, `right_join_spy()`, `inner_join_spy()`, `full_join_spy()` - Join wrappers with diagnostics

## Issue Detection

- Duplicate key detection with row locations
- Whitespace detection (leading/trailing spaces)
- Case mismatch detection
- Encoding issue detection (UTF-8 vs Latin-1, invisible Unicode)
- NA key detection
- Cardinality analysis (1:1, 1:many, many:1, many:many)

## S3 Methods

- `print()`, `summary()`, `plot()` methods for JoinReport objects

## Documentation

- Getting started vignette
- Common issues troubleshooting guide
