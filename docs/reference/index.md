# Package index

## Pre-Join Diagnostics

Analyze tables before joining

- [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
  : Comprehensive Pre-Join Diagnostic Report
- [`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
  : Quick Key Quality Check
- [`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)
  : Find Duplicate Keys

## Post-Join Diagnostics

Understand what happened after a join

- [`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
  : Explain Row Count Changes After a Join
- [`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md)
  : Compare Data Frame Before and After Join

## Safe Join Wrappers

Joins with built-in diagnostics

- [`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
  : Strict Join with Cardinality Enforcement
- [`left_join_spy()`](https://gillescolling.com/joinspy/reference/left_join_spy.md)
  : Left Join with Diagnostics
- [`right_join_spy()`](https://gillescolling.com/joinspy/reference/right_join_spy.md)
  : Right Join with Diagnostics
- [`inner_join_spy()`](https://gillescolling.com/joinspy/reference/inner_join_spy.md)
  : Inner Join with Diagnostics
- [`full_join_spy()`](https://gillescolling.com/joinspy/reference/full_join_spy.md)
  : Full Join with Diagnostics
- [`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
  : Get the Last Join Report

## Auto-Repair

Fix common key issues automatically

- [`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
  : Repair Common Key Issues
- [`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
  : Suggest Repair Code

## Advanced Analysis

Cardinality detection and multi-table chains

- [`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
  : Detect Join Relationship Type
- [`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
  : Detect Potential Cartesian Product
- [`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md)
  : Analyze Multi-Table Join Chain

## Visualization

Plot and summarize join diagnostics

- [`plot_venn()`](https://gillescolling.com/joinspy/reference/plot_venn.md)
  : Plot Venn Diagram of Key Overlap
- [`plot_summary()`](https://gillescolling.com/joinspy/reference/plot_summary.md)
  : Plot Join Summary Table

## S3 Methods

Methods for JoinReport objects

- [`print(`*`<JoinReport>`*`)`](https://gillescolling.com/joinspy/reference/print.JoinReport.md)
  : Print Method for JoinReport
- [`summary(`*`<JoinReport>`*`)`](https://gillescolling.com/joinspy/reference/summary.JoinReport.md)
  : Summary Method for JoinReport
- [`plot(`*`<JoinReport>`*`)`](https://gillescolling.com/joinspy/reference/plot.JoinReport.md)
  : Plot Method for JoinReport

## Logging & Audit

Log reports for reproducibility

- [`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
  : Log Join Report to File
- [`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
  : Configure Automatic Logging
- [`get_log_file()`](https://gillescolling.com/joinspy/reference/get_log_file.md)
  : Get Current Log File

## Helpers

- [`is_join_report()`](https://gillescolling.com/joinspy/reference/is_join_report.md)
  : Check if Object is a JoinReport
