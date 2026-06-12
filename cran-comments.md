## Submission

joinspy 0.8.3 is a patch release submitted soon after 0.8.2 to fix a correctness
bug: when the right-hand side was a data.table, the join renamed key columns in
place, altering the caller's object. The table is now copied before renaming, so
a user's data is no longer changed as a side effect. The release also lets
join_explain() infer the join type from row counts when it is not supplied, and
expands the vignettes. See NEWS.md for the full list.

I am aware of the "Days since last update: 1" NOTE. The quick follow-up is to
correct the in-place modification above, which can silently change a user's data.

## Test environments

- Local: Windows 11, R 4.6.0
- win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 1 note

The only NOTE is "Days since last update: 1" (see above).

## Reverse dependencies

joinspy has no reverse dependencies on CRAN.
