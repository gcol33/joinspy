# Story: joinspy

## Claim
Diagnostic tools for data frame joins: checks the key columns of two tables before the join, names the values that will not match and why, and repairs them.

## Audience
R users who join tables from different sources (exports, databases, spreadsheets) with base R, dplyr or data.table, and who have met a join that silently dropped or multiplied rows.

## Relation
- to: none (joins themselves run in base `merge()`, dplyr or data.table)
- phrase: none
- home: README, Related packages (dplyr `relationship`, powerjoin, joyn, tidylog)

## Arcs

### A1 Why the keys do not match
- question: "the keys look the same, why does the join miss?"
- answer: whitespace, case, invisible Unicode, encodings, empty strings, type and factor mismatches, floating-point keys, near-match typos, named per value
- payoff: the reader knows which values fail and why before joining
- evidence: R/string_diagnostics.R, tests
- home: vignettes/why-keys-dont-match.Rmd
- also: README (What the report checks), Quick Start

### A2 Repairing the keys
- question: "how do I fix them without hand-editing?"
- answer: `join_repair()` with dry run, `suggest_repairs()` emits code
- home: vignettes/common-issues.Rmd
- also: README (Usage), Quick Start

### A3 Predictable row counts
- question: "will this join explode or lose rows?"
- answer: predicted row counts per join type; `join_strict()` enforces the declared relationship; `join_explain()` accounts for a result
- home: vignettes/production.Rmd
- also: README (Declaring the relationship of the keys, Explaining a join that already ran)

### A4 Works with the reader's join engine
- question: "do I have to change how I join?"
- answer: tibbles use dplyr, data.tables use data.table, data frames use `merge()`; class preserved
- home: vignettes/backends.Rmd
- also: README (supports list)

## Non-goals
- Fuzzy or approximate joining: near matches are reported, never joined.

## Documents
- DESCRIPTION: claim, A1, A3
- README / landing: claim, first diagnosis and repair, one section per A1 and A3, routing
- Quick Start (quickstart.Rmd): tour of every feature
- why-keys-dont-match.Rmd: explanation, A1
- common-issues.Rmd: how-to per problem, A2
- production.Rmd: how-to, A3 in pipelines
- backends.Rmd: explanation, A4

## Open
- The Get started article is titled "Quick Start"; pkgdown links it as Get Started in the navbar.
