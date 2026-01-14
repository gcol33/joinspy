# joinspy Roadmap

## Phase 1: Core Implementation (v0.1.0) ✅ COMPLETE

### Infrastructure
- [x] `JoinReport` S3 class and print method
- [x] `string_diagnostics.R` utilities (whitespace, encoding, case detection)
- [x] NAMESPACE generation via roxygen2

### Core Functions
- [x] `join_spy()` - Comprehensive pre-join diagnostic report
- [x] `key_check()` - Quick key quality assessment
- [x] `key_duplicates()` - Find and locate duplicate keys
- [x] `join_explain()` - Explain row count changes post-join
- [x] `join_diff()` - Before/after state comparison
- [x] `join_strict()` - Join with cardinality enforcement

### Join Wrappers
- [x] `left_join_spy()`
- [x] `right_join_spy()`
- [x] `inner_join_spy()`
- [x] `full_join_spy()`

### Issue Detection (v0.1.0)
- [x] Duplicate key detection with row locations
- [x] Whitespace detection (leading/trailing spaces)
- [x] Case mismatch detection
- [x] Encoding issue detection (UTF-8 vs Latin-1, invisible Unicode)
- [x] NA key detection
- [x] Cardinality analysis (1:1, 1:many, many:1, many:many)

### Tests & Documentation
- [x] Comprehensive test suite for all functions (117 tests)
- [x] `introduction.Rmd` vignette
- [x] `common-issues.Rmd` vignette

---

## Phase 2: Enhanced Detection (v0.2.0) ✅ COMPLETE

### Type & Format Issues
- [x] Type coercion warnings (character to factor, numeric-as-string to numeric)
- [x] Factor level mismatches between tables
- [x] Empty string vs NA distinction (behave differently in joins)
- [x] Numeric precision warnings for floating-point keys

### Near-Match Detection
- [x] Fuzzy match candidates (Levenshtein distance ≤ 2)
- [x] Suggest potential matches for unmatched keys
- [x] Configurable similarity threshold

### Multi-Column Join Analysis
- [x] Per-column breakdown for composite keys (which column causes mismatch)
- [x] Problem column identification (lowest match rate)

---

## Phase 3: Auto-Fix & Repair (v0.3.0) ✅ COMPLETE

### Repair Functions
- [x] `join_repair()` - Automatically fix trivial issues
  - Trim whitespace
  - Standardize case (to lower/upper)
  - Remove invisible characters
  - Convert empty strings to NA
- [x] `suggest_repairs()` - Return code snippets to fix detected issues
- [x] Dry-run mode - Show what would be fixed without modifying

---

## Phase 4: Performance & Scale (v0.4.0) ✅ COMPLETE

### Large Dataset Support
- [x] Sampling mode: `join_spy(x, y, by, sample = 10000)`
- [x] Memory estimation for join result
- [x] Reproducible sampling with seed

---

## Phase 5: Visualization (v0.5.0) ✅ COMPLETE

### Diagrams
- [x] `plot_venn()` - Venn diagram of key overlap (PNG/SVG/PDF export)
- [x] `plot_summary()` - Summary tables (text/markdown/data.frame)

---

## Phase 6: Advanced Join Patterns (v0.6.0) ✅ COMPLETE

### Specialized Joins
- [x] `check_cartesian()` - Cross-join/Cartesian product warnings
- [x] `detect_cardinality()` - Determine actual cardinality relationship

### Multi-Table Analysis
- [x] `analyze_join_chain()` - Cascading join analysis for multi-table chains

---

## Phase 7: Integration (v0.7.0) ✅ COMPLETE

### IDE Integration
- [x] RStudio addin for interactive exploration (`addin_join_inspector`)
- [x] Shiny gadget with table/column selection

### Logging & Audit
- [x] `log_report()` - Write reports to file (text/JSON/RDS)
- [x] `set_log_file()` / `get_log_file()` - Automatic logging configuration

### Pipe-Friendly Enhancements
- [x] Silent mode: `x %>% left_join_spy(y, by, .quiet = TRUE)`
- [x] `last_report()` - Deferred report access

---

## Summary

| Phase | Status | Tests | Functions |
|-------|--------|-------|-----------|
| 1 - Core | ✅ Complete | 117 | 11 |
| 2 - Enhanced Detection | ✅ Complete | +18 | +7 internal |
| 3 - Auto-Fix | ✅ Complete | +5 | 2 |
| 4 - Performance | ✅ Complete | +2 | sampling + memory |
| 5 - Visualization | ✅ Complete | +2 | 2 |
| 6 - Advanced | ✅ Complete | +6 | 3 |
| 7 - Integration | ✅ Complete | +0 | 4 |
| **Total** | **7/7 phases** | **159** | **22 exported** |
