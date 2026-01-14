# Common Join Issues and Solutions

## Overview

This vignette catalogs common join problems and shows how joinspy
detects and resolves them. Each issue includes detection methods and
recommended solutions.

## Issue 1: Duplicate Keys

**Problem**: When one or both tables have duplicate keys, joins multiply
rows unexpectedly.

``` r

orders <- data.frame(
  customer_id = c(1, 2, 2, 3),
  amount = c(100, 50, 75, 200)
)

addresses <- data.frame(
  customer_id = c(1, 2, 2, 3),
  address = c("NYC", "LA", "SF", "Chicago")
)

join_spy(orders, addresses, by = "customer_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: customer_id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 4 Unique keys: 3 Duplicate keys: 1 NA keys: 0
#> Right table: Rows: 4 Unique keys: 3 Duplicate keys: 1 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 3
#> Keys only in left: 0
#> Keys only in right: 0
#> Match rate (left): "100%"
#> 
#> ── Issues Detected ──
#> 
#> ! Left table has 1 duplicate key(s) affecting 2 rows - may cause row multiplication
#> ! Right table has 1 duplicate key(s) affecting 2 rows - may cause row multiplication
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 6
#> left_join: 6
#> right_join: 6
#> full_join: 6
```

**Detection**:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
reports duplicate counts and expected row multiplication.

**Solution**: Aggregate or filter duplicates before joining.

``` r

key_duplicates(orders, by = "customer_id")
#>   customer_id amount .n_duplicates
#> 2           2     50             2
#> 3           2     75             2
key_duplicates(addresses, by = "customer_id")
#>   customer_id address .n_duplicates
#> 2           2      LA             2
#> 3           2      SF             2
```

## Issue 2: Whitespace

**Problem**: Invisible leading/trailing spaces prevent matches.

``` r

sales <- data.frame(
  product = c("Widget", "Gadget ", " Gizmo"),
  units = c(10, 20, 30),
  stringsAsFactors = FALSE
)

inventory <- data.frame(
  product = c("Widget", "Gadget", "Gizmo"),
  stock = c(100, 200, 300),
  stringsAsFactors = FALSE
)

join_spy(sales, inventory, by = "product")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: product
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 1
#> Keys only in left: 2
#> Keys only in right: 2
#> Match rate (left): "33.3%"
#> 
#> ── Issues Detected ──
#> 
#> ! Left column 'product' has 2 value(s) with leading/trailing whitespace
#> ℹ 2 near-match(es) found (e.g., 'Gadget ' ~ 'Gadget', ' Gizmo' ~ 'Gizmo') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 1
#> left_join: 3
#> right_join: 3
#> full_join: 5
```

**Detection**:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
flags whitespace issues in the Issues section.

**Solution**: Use
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
or [`trimws()`](https://rdrr.io/r/base/trimws.html).

``` r

sales_fixed <- join_repair(sales, by = "product")
#> ✔ Repaired 2 value(s)
key_check(sales_fixed, inventory, by = "product")
#> ✔ Key check passed: no issues detected
```

## Issue 3: Case Mismatches

**Problem**: Keys differ only by case (“ABC” vs “abc”).

``` r

left <- data.frame(
  code = c("ABC", "def", "GHI"),
  value = 1:3,
  stringsAsFactors = FALSE
)

right <- data.frame(
  code = c("abc", "DEF", "ghi"),
  label = c("A", "D", "G"),
  stringsAsFactors = FALSE
)

join_spy(left, right, by = "code")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: code
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 0
#> Keys only in left: 3
#> Keys only in right: 3
#> Match rate (left): "0%"
#> 
#> ── Issues Detected ──
#> 
#> ! 3 key(s) would match if case-insensitive (e.g., 'ABC' vs 'abc')
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 0
#> left_join: 3
#> right_join: 3
#> full_join: 6
```

**Detection**:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
detects case mismatches when keys would match if case-insensitive.

**Solution**: Standardize case with
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md).

``` r

repaired <- join_repair(left, right, by = "code", standardize_case = "upper")
#> ✔ Repaired 3 value(s)
key_check(repaired$x, repaired$y, by = "code")
#> ✔ Key check passed: no issues detected
```

## Issue 4: NA Keys

**Problem**: NA values in key columns never match (by design in R).

``` r

orders <- data.frame(
  customer_id = c(1, NA, 3, NA),
  amount = c(100, 200, 300, 400)
)

customers <- data.frame(
  customer_id = c(1, 2, 3, NA),
  name = c("Alice", "Bob", "Carol", "Unknown")
)

join_spy(orders, customers, by = "customer_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: customer_id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 4 Unique keys: 2 Duplicate keys: 0 NA keys: 2
#> Right table: Rows: 4 Unique keys: 3 Duplicate keys: 0 NA keys: 1
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 0
#> Keys only in right: 1
#> Match rate (left): "100%"
#> 
#> ── Issues Detected ──
#> 
#> ! Left table has 2 NA key(s) - these will not match
#> ! Right table has 1 NA key(s) - these will not match
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 4
#> right_join: 4
#> full_join: 6
```

**Detection**:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
reports NA counts in the Table Summary.

**Solution**: Handle NA values explicitly—remove them or replace with a
placeholder.

``` r

# Option 1: Remove rows with NA keys
orders_clean <- orders[!is.na(orders$customer_id), ]

# Option 2: Replace NA with placeholder
orders$customer_id[is.na(orders$customer_id)] <- -999
```

## Issue 5: No Matches

**Problem**: Inner join returns zero rows when you expected matches.

``` r

system_a <- data.frame(
  user_id = c("USR001", "USR002", "USR003"),
  score = c(85, 90, 78),
  stringsAsFactors = FALSE
)

system_b <- data.frame(
  user_id = c("1", "2", "3"),
  department = c("Sales", "Marketing", "Engineering"),
  stringsAsFactors = FALSE
)

report <- join_spy(system_a, system_b, by = "user_id")
```

**Detection**: Match analysis shows 0% match rate.

**Solution**: Create a mapping table or transform keys to a common
format.

``` r

# Extract numeric part
system_a$user_num <- gsub("USR0*", "", system_a$user_id)
key_check(system_a, system_b, by = c("user_num" = "user_id"))
#> ✔ Key check passed: no issues detected
```

## Issue 6: Many-to-Many Explosion

**Problem**: Both tables have duplicate keys, causing exponential row
growth.

``` r

order_items <- data.frame(
  order_id = c(1, 1, 2, 2, 2),
  item = c("A", "B", "C", "D", "E")
)

order_payments <- data.frame(
  order_id = c(1, 1, 2, 2),
  payment = c("CC1", "CC2", "Cash", "Check")
)

report <- join_spy(order_items, order_payments, by = "order_id")
```

**Detection**: Expected row counts show multiplication (inner join = 10
rows from 9 source rows).

**Solution**: Aggregate one table first, or use
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md).

``` r

check_cartesian(order_items, order_payments, by = "order_id")
#> ✔ No Cartesian product risk (expansion factor: 2x)
```

``` r

# Enforce cardinality to catch this
join_strict(order_items, order_payments, by = "order_id", expect = "1:m")
#> Error:
#> ! Cardinality violation: expected 1:m but found m:m
#>   Left duplicates: 2, Right duplicates: 2
```

## Issue 7: Type Mismatches

**Problem**: Keys have different types (numeric vs character).

``` r

orders <- data.frame(
  product_id = c(1, 2, 3),
  quantity = c(10, 20, 30)
)

products <- data.frame(
  product_id = c("1", "2", "3"),
  name = c("Widget", "Gadget", "Gizmo"),
  stringsAsFactors = FALSE
)

join_spy(orders, products, by = "product_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: product_id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 3
#> Keys only in left: 0
#> Keys only in right: 0
#> Match rate (left): "100%"
#> 
#> ── Issues Detected ──
#> 
#> ! Type mismatch: 'product_id' is numeric, 'product_id' is character - may cause unexpected results
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 3
#> left_join: 3
#> right_join: 3
#> full_join: 3
```

**Detection**:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
flags type coercion warnings.

**Solution**: Convert to matching types before joining.

``` r

orders$product_id <- as.character(orders$product_id)
key_check(orders, products, by = "product_id")
#> ✔ Key check passed: no issues detected
```

## Issue 8: Empty Strings vs NA

**Problem**: Empty strings (`""`) and `NA` behave differently in joins.

``` r

left <- data.frame(
  id = c("A", "", "C"),
  value = 1:3,
  stringsAsFactors = FALSE
)

right <- data.frame(
  id = c("A", "B", ""),
  label = c("Alpha", "Beta", "Empty"),
  stringsAsFactors = FALSE
)

join_spy(left, right, by = "id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 1
#> Keys only in right: 1
#> Match rate (left): "66.7%"
#> 
#> ── Issues Detected ──
#> 
#> ℹ Left column 'id' has 1 empty string(s) - these match other empty strings but not NA
#> ℹ Right column 'id' has 1 empty string(s) - these match other empty strings but not NA
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: NA
#> left_join: NA
#> right_join: NA
#> full_join: NA
```

**Detection**:
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
warns about empty strings in keys.

**Solution**: Convert empty strings to NA with
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md).

``` r

left_fixed <- join_repair(left, by = "id", empty_to_na = TRUE)
#> ✔ Repaired 1 value(s)
left_fixed$id
#> [1] "A" NA  "C"
```

## Using join_strict() for Safety

When you know the expected cardinality, use
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
to fail fast:

``` r

products <- data.frame(id = 1:3, name = c("A", "B", "C"))
prices <- data.frame(id = c(1, 2, 2, 3), price = c(10, 20, 25, 30))

join_strict(products, prices, by = "id", expect = "1:1")
#> Error:
#> ! Cardinality violation: expected 1:1 but found 1:m
#>   Left duplicates: 0, Right duplicates: 1
```

## Automatic Detection with detect_cardinality()

Let joinspy determine the actual relationship:

``` r

orders <- data.frame(id = c(1, 1, 2, 3), item = c("A", "B", "C", "D"))
customers <- data.frame(id = 1:3, name = c("Alice", "Bob", "Carol"))

detect_cardinality(orders, customers, by = "id")
#> ℹ Detected cardinality: "m:1"
#> Left duplicates: 1 key(s)
```

## Quick Reference

| Issue | Detection | Solution |
|----|----|----|
| Duplicates | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md), [`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md) | Aggregate or filter |
| Whitespace | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md), [`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md) | [`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md), [`trimws()`](https://rdrr.io/r/base/trimws.html) |
| Case mismatch | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) | `join_repair(standardize_case=)` |
| NA keys | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) Table Summary | Remove or replace |
| No matches | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) Match Analysis | Check key format/mapping |
| M:M explosion | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md), [`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md) | Aggregate first |
| Type mismatch | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) | Convert types |
| Empty strings | [`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md) | `join_repair(empty_to_na=TRUE)` |

## Troubleshooting Workflow

1.  Run `join_spy(x, y, by)` to get a comprehensive diagnostic
2.  Check the Issues section for detected problems
3.  Use
    [`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)
    to locate specific duplicate rows
4.  Apply
    [`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
    to fix whitespace/case/encoding issues
5.  Use
    [`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
    to enforce expected cardinality
6.  After joining, use
    [`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
    to understand row count changes

## See Also

- [`vignette("introduction")`](https://gillescolling.com/joinspy/articles/introduction.md) -
  Getting started guide
- [`?join_spy`](https://gillescolling.com/joinspy/reference/join_spy.md),
  [`?key_check`](https://gillescolling.com/joinspy/reference/key_check.md),
  [`?join_repair`](https://gillescolling.com/joinspy/reference/join_repair.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)
- [`?check_cartesian`](https://gillescolling.com/joinspy/reference/check_cartesian.md),
  [`?detect_cardinality`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)

## Session Info

``` r

sessionInfo()
#> R version 4.5.2 (2025-10-31 ucrt)
#> Platform: x86_64-w64-mingw32/x64
#> Running under: Windows 11 x64 (build 26200)
#> 
#> Matrix products: default
#>   LAPACK version 3.12.1
#> 
#> locale:
#> [1] LC_COLLATE=English_United States.utf8 
#> [2] LC_CTYPE=English_United States.utf8   
#> [3] LC_MONETARY=English_United States.utf8
#> [4] LC_NUMERIC=C                          
#> [5] LC_TIME=English_United States.utf8    
#> 
#> time zone: Europe/Luxembourg
#> tzcode source: internal
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] joinspy_0.7.2
#> 
#> loaded via a namespace (and not attached):
#>  [1] vctrs_0.6.5       cli_3.6.5         knitr_1.51        rlang_1.1.6      
#>  [5] xfun_0.55         otel_0.2.0        textshaping_1.0.4 jsonlite_2.0.0   
#>  [9] glue_1.8.0        htmltools_0.5.9   ragg_1.5.0        sass_0.4.10      
#> [13] rmarkdown_2.30    evaluate_1.0.5    jquerylib_0.1.4   fastmap_1.2.0    
#> [17] yaml_2.3.12       lifecycle_1.0.5   compiler_4.5.2    fs_1.6.6         
#> [21] htmlwidgets_1.6.4 systemfonts_1.3.1 digest_0.6.39     R6_2.6.1         
#> [25] pillar_1.11.1     bslib_0.9.0       tools_4.5.2       pkgdown_2.2.0    
#> [29] cachem_1.1.0      desc_1.4.3
```
