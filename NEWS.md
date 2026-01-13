# joinspy 0.1.0

Initial release.

## Core Functions

* `join_spy()` - Comprehensive pre-join diagnostic report
* `key_check()` - Quick key quality assessment
* `key_duplicates()` - Find and locate duplicate keys
* `join_explain()` - Explain row count changes post-join
* `join_strict()` - Join with cardinality enforcement
* `left_join_spy()`, `right_join_spy()`, `inner_join_spy()`, `full_join_spy()` - Join wrappers with diagnostics

## Issue Detection

* Duplicate key detection with row locations
* Whitespace detection (leading/trailing spaces)
* Case mismatch detection
* Encoding issue detection
* NA key detection
* Cardinality analysis (1:1, 1:many, many:1, many:many)
