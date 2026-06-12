## Submission

joinspy 0.8.3 is a patch release. It fixes a correctness bug where the safe
join wrappers modified the caller's data.table in place when the right-hand
side was a data.table; the input is now copied before renaming. It also lets
join_explain() infer the join type from row counts when not supplied, and
expands the vignettes. See NEWS.md for the full list.

## Test environments

- Local: Windows 11, R 4.6.0
- win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

joinspy has no reverse dependencies on CRAN.
