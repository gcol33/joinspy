# Create a JoinReport Object

Create a JoinReport Object

## Usage

``` r
new_join_report(
  x_summary,
  y_summary,
  match_analysis,
  issues,
  expected_rows,
  by
)
```

## Arguments

- x_summary:

  Summary statistics for keys in the left table.

- y_summary:

  Summary statistics for keys in the right table.

- match_analysis:

  Details of which keys will/won't match.

- issues:

  List of detected problems.

- expected_rows:

  Predicted row counts for each join type.

- by:

  The columns used for joining.

## Value

A `JoinReport` S3 object.
