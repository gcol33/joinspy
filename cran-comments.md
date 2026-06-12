## Submission

joinspy 0.8.2 is a patch release. It fixes several diagnostic correctness
bugs (duplicate-key counts in logged reports, NA handling in composite keys,
integer overflow in row-count predictions, an unimported operator that broke
the package on R 4.1-4.3) and refactors shared key-handling logic into single
sources of truth. See NEWS.md for the full list.

## Test environments

- Local: Windows 11, R 4.6.0
- win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

joinspy has no reverse dependencies on CRAN.
