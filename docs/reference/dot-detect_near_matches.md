# Detect Near-Matches Between Keys

Finds keys that almost match (small edit distance).

## Usage

``` r
.detect_near_matches(x_keys, y_keys, max_distance = 2, max_candidates = 10)
```

## Arguments

- x_keys:

  Unique keys from left table.

- y_keys:

  Unique keys from right table.

- max_distance:

  Maximum 'Levenshtein' distance to consider a near-match.

- max_candidates:

  Maximum number of near-match candidates to return.

## Value

A list with near-match information.
