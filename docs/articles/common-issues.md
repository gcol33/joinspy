# Common Join Problems

Trailing spaces, flipped case, and zero-width Unicode characters make
keys that look identical on screen compare as different during a join.

This vignette covers the issues joinspy detects, ordered roughly by
frequency. String-level issues come first, then structural ones
(duplicates, NAs, type mismatches, Cartesian explosions).

## Trailing and leading whitespace

The classic. Someone exports a CSV from Excel, and now half the keys
carry a trailing space. Everything looks fine when we print the data
frame. Nothing matches when we join.

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

Two of three keys carry whitespace that prevents matching.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
strips it:

``` r

sales_clean <- join_repair(sales, by = "product")
#> ✔ Repaired 2 value(s)
key_check(sales_clean, inventory, by = "product")
#> ✔ Key check passed: no issues detected
```

Passing `dry_run = TRUE` previews the repair without applying it.

The problem compounds with composite keys – whitespace in *any* column
is enough to break the match:

``` r

shipments <- data.frame(
  warehouse = c("East ", "West", "East "),
  product   = c("Widget", "Gadget ", "Gizmo"),
  shipped   = c(50, 80, 35),
  stringsAsFactors = FALSE
)

stock <- data.frame(
  warehouse = c("East", "West", "East"),
  product   = c("Widget", "Gadget", "Gizmo"),
  on_hand   = c(200, 150, 90),
  stringsAsFactors = FALSE
)

join_spy(shipments, stock, by = c("warehouse", "product"))
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: warehouse, product
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
#> ! Left column 'warehouse' has 1 value(s) with leading/trailing whitespace
#> ℹ 1 near-match(es) found (e.g., 'East ' ~ 'East') - possible typos?
#> ! Left column 'product' has 1 value(s) with leading/trailing whitespace
#> ℹ 1 near-match(es) found (e.g., 'Gadget ' ~ 'Gadget') - possible typos?
#> 
#> ── Per-Column Breakdown ──
#> 
#> warehouse: "50%" match rate (1/2)
#> product: "66.7%" match rate (2/3)
#> ℹ Lowest match rate: warehouse
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 0
#> left_join: 3
#> right_join: 3
#> full_join: 6
```

Both `warehouse` and `product` carry trailing spaces in `shipments`, so
all three rows fail to match. A single
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
call cleans every key column at once:

``` r

shipments_clean <- join_repair(shipments, by = c("warehouse", "product"))
#> ✔ Repaired 3 value(s)
key_check(shipments_clean, stock, by = c("warehouse", "product"))
#> ✔ Key check passed: no issues detected
```

## Case mismatches

Databases are often case-insensitive; R is not. When we pull tables from
two different systems, one might store `"ABC"` and the other `"abc"`.

``` r

sensors <- data.frame(
  station = c("AWS-01", "aws-02", "Aws-03"),
  temp = c(22.1, 18.4, 25.7),
  stringsAsFactors = FALSE
)

metadata <- data.frame(
  station = c("aws-01", "AWS-02", "AWS-03"),
  region = c("North", "South", "East"),
  stringsAsFactors = FALSE
)
```

None of these keys match as-is:

``` r

join_spy(sensors, metadata, by = "station")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: station
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
#> ! 3 key(s) would match if case-insensitive (e.g., 'AWS-01' vs 'aws-01')
#> ℹ 5 near-match(es) found (e.g., 'AWS-01' ~ 'AWS-02', 'AWS-01' ~ 'AWS-03', 'aws-02' ~ 'aws-01') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 0
#> left_join: 3
#> right_join: 3
#> full_join: 6
```

We can repair both sides to a common case:

``` r

repaired <- join_repair(sensors, metadata, by = "station", standardize_case = "lower")
#> ✔ Repaired 4 value(s)
key_check(repaired$x, repaired$y, by = "station")
#> ✔ Key check passed: no issues detected
```

`"lower"`, `"upper"`, and `"title"` all work. One thing to watch for: if
the key column is a `factor`, case standardization changes the level
labels but not the underlying integer codes. Converting to character
first avoids silently merging distinct factor levels.

## Encoding and invisible characters

A key contains a non-breaking space (U+00A0) instead of a regular space,
or a zero-width joiner crept in during a copy-paste from a PDF. The
strings print identically but do not match.

``` r

# Simulate a non-breaking space in one key
left <- data.frame(
  city = c("New York", "Los\u00a0Angeles", "Chicago"),
  pop = c(8.3, 3.9, 2.7),
  stringsAsFactors = FALSE
)

right <- data.frame(
  city = c("New York", "Los Angeles", "Chicago"),
  area = c(302, 469, 227),
  stringsAsFactors = FALSE
)

join_spy(left, right, by = "city")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: city
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
#> ! Left column 'city' has encoding issues (invisible chars or mixed encoding)
#> ℹ 1 near-match(es) found (e.g., 'Los Angeles' ~ 'Los Angeles') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 3
#> right_join: 3
#> full_join: 4
```

The `"Los\u00a0Angeles"` key in `left` looks like `"Los Angeles"` in
`right`, but the non-breaking space makes them different byte sequences.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
with `remove_invisible = TRUE` (the default) strips these out:

``` r

left_fixed <- join_repair(left, by = "city")
#> ✔ Repaired 1 value(s)
key_check(left_fixed, right, by = "city")
#> ✔ Key check passed: no issues detected
```

Common sources include PDF extraction, web scraping, and cross-platform
file transfers.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
handles the most common offenders: non-breaking spaces, zero-width
joiners, BOM markers, and soft hyphens. It does not attempt full Unicode
normalization (NFC vs. NFD); for that we would reach for
[`stringi::stri_trans_nfc()`](https://rdrr.io/pkg/stringi/man/stri_trans_nf.html).

If
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
still flags encoding issues after repair,
[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
on a report will print the exact R code needed.

## Empty strings masquerading as data

Empty strings (`""`) are valid character values in R. They will match
other empty strings in a join, which is almost never what we want: two
rows with missing identifiers get joined as though they refer to the
same entity.

``` r

patients <- data.frame(
  mrn = c("P001", "", "P003"),
  age = c(34, 56, 29),
  stringsAsFactors = FALSE
)

visits <- data.frame(
  mrn = c("P001", "P002", ""),
  date = c("2024-01-10", "2024-02-15", "2024-03-20"),
  stringsAsFactors = FALSE
)

join_spy(patients, visits, by = "mrn")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: mrn
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
#> ℹ Left column 'mrn' has 1 empty string(s) - these match other empty strings but not NA
#> ℹ Right column 'mrn' has 1 empty string(s) - these match other empty strings but not NA
#> ℹ 2 near-match(es) found (e.g., 'P003' ~ 'P001', 'P003' ~ 'P002') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: NA
#> left_join: NA
#> right_join: NA
#> full_join: NA
```

Converting empties to `NA` before joining fixes this, since NAs never
match in R:

``` r

patients_fixed <- join_repair(patients, by = "mrn", empty_to_na = TRUE)
#> ✔ Repaired 1 value(s)
patients_fixed$mrn
#> [1] "P001" NA     "P003"
```

Note that `data.table` treats `""` and `NA_character_` as distinct in
keyed joins, so when using a data.table backend we need to convert empty
strings to `NA` on both sides.

## Near-matches and typos

Sometimes keys are close but not identical. These are not whitespace or
case problems – they are genuine mismatches that
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
flags when it finds keys in one table with no counterpart in the other.

``` r

orders <- data.frame(
  sku = c("WDG-100", "GDG-200", "GZM-300"),
  qty = c(5, 12, 8),
  stringsAsFactors = FALSE
)

catalog <- data.frame(
  sku = c("WDG-100", "GDG-200", "GZM-301"),
  price = c(9.99, 14.99, 7.50),
  stringsAsFactors = FALSE
)

report <- join_spy(orders, catalog, by = "sku")
```

Internally,
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
computes Levenshtein distances between unmatched keys. When two keys
differ by only one or two characters, the report flags them as
near-matches. Here is a clearer example with multiple near-matches:

``` r

employees <- data.frame(
  name = c("Johnson", "Smithe", "O'Brian", "Williams"),
  dept = c("Sales", "R&D", "Ops", "HR"),
  stringsAsFactors = FALSE
)

payroll <- data.frame(
  name = c("Jonhson", "Smith", "O'Brien", "Williams"),
  salary = c(55000, 62000, 48000, 71000),
  stringsAsFactors = FALSE
)

report <- join_spy(employees, payroll, by = "name")
```

`"Johnson"` vs. `"Jonhson"` (transposition), `"Smithe"` vs. `"Smith"`
(extra character), and `"O'Brian"` vs. `"O'Brien"` (vowel swap) are all
within edit distance 2. `"Williams"` matches exactly. There is no
automated fix here since joinspy cannot know which side is correct, but
the near-match list gives a concrete starting point for building a
lookup table.

## Duplicate keys

Duplicate keys cause row multiplication. A left join on a key that
appears twice in the right table doubles the corresponding rows from the
left.

``` r

orders <- data.frame(
  customer_id = c(1, 2, 3),
  amount = c(100, 250, 75)
)

addresses <- data.frame(
  customer_id = c(1, 2, 2, 3),
  address = c("NYC", "LA", "SF", "Chicago"),
  stringsAsFactors = FALSE
)

join_spy(orders, addresses, by = "customer_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: customer_id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
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
#> ! Right table has 1 duplicate key(s) affecting 2 rows - may cause row multiplication
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 4
#> left_join: 4
#> right_join: 4
#> full_join: 4
```

[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)
shows which rows are responsible:

``` r

key_duplicates(addresses, by = "customer_id")
#>   customer_id address .n_duplicates
#> 2           2      LA             2
#> 3           2      SF             2
```

If each customer should have one address, we deduplicate first. If we
genuinely need all combinations, the multiplication is correct – we just
need to know it will happen.

When *both* sides have duplicates, each key group produces a Cartesian
product:

``` r

orders_dup <- data.frame(
  product = c("A", "A", "B", "B"),
  qty     = c(10, 20, 5, 15)
)

prices_dup <- data.frame(
  product = c("A", "A", "A", "B", "B"),
  price   = c(1.0, 1.1, 1.2, 2.0, 2.5)
)

join_spy(orders_dup, prices_dup, by = "product")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: product
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 4 Unique keys: 2 Duplicate keys: 2 NA keys: 0
#> Right table: Rows: 5 Unique keys: 2 Duplicate keys: 2 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 2
#> Keys only in left: 0
#> Keys only in right: 0
#> Match rate (left): "100%"
#> 
#> ── Issues Detected ──
#> 
#> ! Left table has 2 duplicate key(s) affecting 4 rows - may cause row multiplication
#> ! Right table has 2 duplicate key(s) affecting 5 rows - may cause row multiplication
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 10
#> left_join: 10
#> right_join: 10
#> full_join: 10
```

Product `"A"` has 2 rows on the left and 3 on the right, so a join
produces 2 x 3 = 6 rows for that key alone.
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
quantifies the total expansion before we run the join:

``` r

check_cartesian(orders_dup, prices_dup, by = "product")
#> ✔ No Cartesian product risk (expansion factor: 2x)
```

## NA keys

`NA` never equals `NA` in R. This is by design, but it surprises people
who expect two missing values to match.

``` r

orders <- data.frame(
  customer_id = c(1, NA, 3, NA),
  amount = c(100, 200, 300, 400)
)

customers <- data.frame(
  customer_id = c(1, 2, 3, NA),
  name = c("Alice", "Bob", "Carol", "Unknown"),
  stringsAsFactors = FALSE
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

We can either remove rows with NA keys before joining, or replace NAs
with a sentinel value if we actually want them to match:

``` r

# Remove
orders_clean <- orders[!is.na(orders$customer_id), ]
key_check(orders_clean, customers, by = "customer_id")
#> ! Key check found 1 issue(s):
#> ✖ Right table has 1 NA key(s)
```

## Type mismatches

One table stores IDs as integers, the other as character strings.
[`merge()`](https://rdrr.io/r/base/merge.html) coerces silently;
[`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
refuses. Either way, we want to know about it before the join.

``` r

invoices <- data.frame(
  product_id = c(1, 2, 3),
  total = c(500, 300, 150)
)

products <- data.frame(
  product_id = c("1", "2", "3"),
  name = c("Widget", "Gadget", "Gizmo"),
  stringsAsFactors = FALSE
)

join_spy(invoices, products, by = "product_id")
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

A subtler variant occurs with `Date` vs. character, or `POSIXct`
vs. `Date`, where the join either fails or coerces through numeric
intermediaries.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
flags the type mismatch regardless of the types involved.

``` r

invoices$product_id <- as.character(invoices$product_id)
key_check(invoices, products, by = "product_id")
#> ✔ Key check passed: no issues detected
```

## Many-to-many explosions

When both tables have duplicate keys, we get a Cartesian product within
each key group. With real data this can turn a 10,000-row join into a
million-row table.

``` r

items <- data.frame(
  order_id = c(1, 1, 2, 2, 2),
  item = c("A", "B", "C", "D", "E"),
  stringsAsFactors = FALSE
)

payments <- data.frame(
  order_id = c(1, 1, 2, 2),
  method = c("Card", "Cash", "Card", "Wire"),
  stringsAsFactors = FALSE
)

check_cartesian(items, payments, by = "order_id")
#> ✔ No Cartesian product risk (expansion factor: 2x)
```

[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
tells us the relationship type:

``` r

detect_cardinality(items, payments, by = "order_id")
#> ℹ Detected cardinality: "m:m"
#> Left duplicates: 2 key(s)
#> Right duplicates: 2 key(s)
```

If we expected a one-to-many relationship,
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
will stop us before the explosion happens:

``` r

join_strict(items, payments, by = "order_id", type = "left", expect = "1:m")
#> Error:
#> ! Cardinality violation: expected 1:m but found m:m
#>   Left duplicates: 2, Right duplicates: 2
```

## No matches at all

An inner join returns zero rows, and downstream code may not check for
an empty data frame.

``` r

system_a <- data.frame(
  user_id = c("USR-001", "USR-002", "USR-003"),
  score = c(85, 90, 78),
  stringsAsFactors = FALSE
)

system_b <- data.frame(
  user_id = c("1", "2", "3"),
  dept = c("Sales", "R&D", "Ops"),
  stringsAsFactors = FALSE
)

join_spy(system_a, system_b, by = "user_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: user_id
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
#> ── Expected Row Counts ──
#> 
#> inner_join: 0
#> left_join: 3
#> right_join: 3
#> full_join: 6
```

Zero overlap – the keys use completely different formats, and no amount
of trimming or case-folding will help. We need a mapping table or a
transformation that extracts the numeric part:

``` r

system_a$user_num <- gsub("^USR-0*", "", system_a$user_id)
key_check(system_a, system_b, by = c("user_num" = "user_id"))
#> ✔ Key check passed: no issues detected
```

## Troubleshooting workflow

When a join goes wrong, we typically start with
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md).
It checks string quality, key overlap, cardinality, and predicted row
counts in one call:

``` r

report <- join_spy(x, y, by = "key_col")
```

For large datasets, passing `sample = 1000` runs the check on a random
subset first.

If the report flags whitespace, case, encoding, or empty strings,
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
handles them:

``` r

x_clean <- join_repair(x, by = "key_col")
# or both sides:
repaired <- join_repair(x, y, by = "key_col", standardize_case = "lower")
```

If the predicted row count is higher than expected, we inspect
duplicates and decide whether to aggregate or deduplicate:

``` r

key_duplicates(y, by = "key_col")
```

Once keys are clean,
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
enforces the cardinality we expect:

``` r

result <- join_strict(x_clean, y_clean, by = "key_col",
                      type = "left", expect = "1:1")
```

If the joined output still looks wrong,
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
gives a breakdown of what happened:

``` r

result <- left_join_spy(x_clean, y_clean, by = "key_col")
join_explain(result, x_clean, y_clean, by = "key_col")
```

In production pipelines,
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
routes all subsequent reports to a log file, which is useful for
debugging issues after the fact:

``` r

set_log_file("logs/join_diagnostics.log")
# All join_spy() / join_explain() calls now append to this file
```

For pipelines with multiple joins,
[`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md)
diagnoses an entire sequence at once, reporting where the first problem
enters the chain.

## See Also

- [`vignette("quickstart")`](https://gillescolling.com/joinspy/articles/quickstart.md)
  for a quick introduction to joinspy

- [`?join_spy`](https://gillescolling.com/joinspy/reference/join_spy.md),
  [`?join_repair`](https://gillescolling.com/joinspy/reference/join_repair.md),
  [`?key_check`](https://gillescolling.com/joinspy/reference/key_check.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)

- [`?check_cartesian`](https://gillescolling.com/joinspy/reference/check_cartesian.md),
  [`?detect_cardinality`](https://gillescolling.com/joinspy/reference/detect_cardinality.md),
  [`?join_explain`](https://gillescolling.com/joinspy/reference/join_explain.md)
