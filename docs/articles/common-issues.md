# Common Join Problems

Trailing spaces, flipped case, and zero-width Unicode characters make
keys that look identical on screen compare as different during a join.

This vignette covers the issues joinspy detects, ordered roughly by
frequency. String-level issues come first, then structural ones
(duplicates, NAs, type mismatches, Cartesian explosions). Each section
follows the same arc: the symptom, a small dataset that reproduces it,
the diagnosis with joinspy, and the fix. The closing section collects
the individual tools into a numbered workflow we can follow when a join
goes wrong and the cause is unknown.

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

When we want to see what a repair would do before committing to it,
`dry_run = TRUE` prints the planned changes and leaves the data
untouched:

``` r

join_repair(sales, by = "product", dry_run = TRUE)
#> 
#> ── Repair Preview (Dry Run) ────────────────────────────────────────────────────
#> 
#> ── Left table (x) ──
#> 
#> ℹ product: trimmed whitespace (2)
```

Whitespace usually enters at the import boundary. Base
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) keeps it unless
we set `strip.white = TRUE`, while
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
trims by default (`trim_ws = TRUE`). Fixed-width exports and hand-typed
spreadsheet cells are the other common sources; a stray space typed
after a product name survives every visual inspection. Trimming key
columns right after import, before any join, keeps the problem from
spreading into derived tables.

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
all three rows fail to match. The per-column breakdown in the report
shows which component of the composite key drags the match rate down. A
single
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
call cleans every key column at once:

``` r

shipments_clean <- join_repair(shipments, by = c("warehouse", "product"))
#> ✔ Repaired 3 value(s)
key_check(shipments_clean, stock, by = c("warehouse", "product"))
#> ✔ Key check passed: no issues detected
```

Composite keys deserve this check even when each column was cleaned at
some point, because new joins often combine columns that were never used
as keys before.

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

`standardize_case` accepts `"lower"` or `"upper"`. One thing to watch
for:
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
only modifies character columns. A factor key passes through untouched,
with no message, so we convert factors with
[`as.character()`](https://rdrr.io/r/base/character.html) before
repairing; the factor section below shows this in detail. A second
caution applies when case carries meaning. If sample codes `a1` and `A1`
are genuinely different things, folding the case merges them, so we run
[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)
on the folded column before trusting the repair.

Case drift between tables usually means they came from systems with
different conventions. Many SQL collations compare case-insensitively,
so `AWS-01` and `aws-01` are the same row there and different rows in R.
Mixed case inside a single column, as in `sensors` above, more often
points to hand entry. Standardizing to one case at import, and writing
that convention down, prevents the next data pull from reintroducing the
mismatch.

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

When the repair needs to live in a script that does not load joinspy,
[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
turns the report into plain base R that we can paste anywhere:

``` r

report <- join_spy(left, right, by = "city")
suggest_repairs(report)
#> 
#> ── Suggested Repairs ───────────────────────────────────────────────────────────
#> # Remove invisible characters:
#> x[["city"]] <- gsub("[\u200B\u200C\u200D\uFEFF\u00A0]", "", x[["city"]], perl = TRUE)
```

Common sources include PDF extraction, web scraping, and cross-platform
file transfers.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
handles the most common offenders: non-breaking spaces, zero-width
joiners, BOM markers, and soft hyphens. It does not attempt full Unicode
normalization (NFC vs. NFD); for that we would reach for
[`stringi::stri_trans_nfc()`](https://rdrr.io/pkg/stringi/man/stri_trans_nf.html).
When the same feed delivers non-breaking spaces every week, we move the
[`gsub()`](https://rdrr.io/r/base/grep.html) line above into the import
script and raise the issue with whoever owns the producing system.

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

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
lists empty strings as an informational issue: two empty keys do match
each other, so whether that counts as a bug depends on what the rows
mean. Here it would attach an anonymous visit to an anonymous patient.
Converting empties to `NA` before joining fixes this, since NAs never
match in R:

``` r

patients_fixed <- join_repair(patients, by = "mrn", empty_to_na = TRUE)
#> ✔ Repaired 1 value(s)
patients_fixed$mrn
#> [1] "P001" NA     "P003"
```

Passing `y` repairs both tables in one call; the return value is then a
list with elements `x` and `y`:

``` r

both <- join_repair(patients, visits, by = "mrn", empty_to_na = TRUE)
#> ✔ Repaired 2 value(s)
both$y$mrn
#> [1] "P001" "P002" NA
```

Empty strings are what base
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) produces for
blank cells in character columns; only the literal string `"NA"` becomes
missing by default. Passing `na.strings = c("NA", "")` at import keeps
blanks out of the key column entirely, which is cheaper than repairing
after the fact. Note that `data.table` treats `""` and `NA_character_`
as distinct in keyed joins, so when using a data.table backend we need
to convert empty strings to `NA` on both sides.

## Factor keys

Legacy code written under `stringsAsFactors = TRUE`, modeling pipelines,
and some file readers hand us keys stored as factors. A factor key
holding the same labels as a character key joins fine, since R coerces
during the merge, and
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
notes the type difference:

``` r

surveys <- data.frame(
  site = factor(c("North", "South", "East")),
  count = c(12, 7, 30)
)

habitats <- data.frame(
  site = c("North", "South", "East"),
  habitat = c("bog", "meadow", "forest"),
  stringsAsFactors = FALSE
)

join_spy(surveys, habitats, by = "site")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: site
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
#> ℹ Type difference: 'site' is factor, 'site' is character (will be coerced)
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 3
#> left_join: 3
#> right_join: 3
#> full_join: 3
```

All 3 keys match, and the report carries an informational note that the
factor will be coerced. The trap is what factors hide. The string checks
in
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
run on character columns only, so whitespace buried inside factor labels
goes unreported:

``` r

plots <- data.frame(site = factor(c("North ", "South")), richness = c(14, 9))
join_spy(plots, habitats, by = "site")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: site
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 2 Unique keys: 2 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 1
#> Keys only in left: 1
#> Keys only in right: 2
#> Match rate (left): "50%"
#> 
#> ── Issues Detected ──
#> 
#> ℹ Type difference: 'site' is factor, 'site' is character (will be coerced)
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 1
#> left_join: 2
#> right_join: 3
#> full_join: 4
```

The match analysis still does its job (1 of 2 keys matches), but nothing
in the issue list says why. Converting to character first surfaces the
cause:

``` r

plots$site <- as.character(plots$site)
join_spy(plots, habitats, by = "site")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: site
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 2 Unique keys: 2 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 1
#> Keys only in left: 1
#> Keys only in right: 2
#> Match rate (left): "50%"
#> 
#> ── Issues Detected ──
#> 
#> ! Left column 'site' has 1 value(s) with leading/trailing whitespace
#> ℹ 1 near-match(es) found (e.g., 'North ' ~ 'North') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 1
#> left_join: 2
#> right_join: 3
#> full_join: 4
```

Now the whitespace warning appears, along with a near-match pairing
`'North '` with `'North'`.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
follows the same character-only rule: called on the factor version it
returns the data unchanged, with no message. After the conversion it
repairs the key as usual:

``` r

plots_clean <- join_repair(plots, by = "site")
#> ✔ Repaired 1 value(s)
key_check(plots_clean, habitats, by = "site")
#> ✔ Key check passed: no issues detected
```

When both keys are factors,
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
also compares their level sets. Levels that exist on only one side are
reported even when no data row uses them, which catches lookup tables
built against a stale set of categories:

``` r

surveys_f <- data.frame(
  site = factor(c("North", "South"), levels = c("North", "South", "West"))
)
habitats_f <- data.frame(site = factor(c("North", "South", "East")))

join_spy(surveys_f, habitats_f, by = "site")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: site
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 2 Unique keys: 2 Duplicate keys: 0 NA keys: 0
#> Right table: Rows: 3 Unique keys: 3 Duplicate keys: 0 NA keys: 0
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
#> ℹ Factor level mismatch: 1 level(s) only in 'site', 1 level(s) only in 'site'
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 2
#> right_join: 3
#> full_join: 3
```

Here `"West"` is declared on the left and never observed, while `"East"`
exists on the right, so the report counts 1 level unique to each side.
The case section mentioned the level-versus-label trap; here it is
concretely. [`as.numeric()`](https://rdrr.io/r/base/numeric.html) on a
factor returns the internal level codes:

``` r

plot_ids <- factor(c("10", "20", "30"))
as.numeric(plot_ids)
#> [1] 1 2 3
as.numeric(as.character(plot_ids))
#> [1] 10 20 30
```

The direct conversion returns the codes 1, 2, 3, while the route through
[`as.character()`](https://rdrr.io/r/base/character.html) recovers the
labels 10, 20, 30. A key column converted the first way joins against
the wrong rows with no warning, since the codes are perfectly valid
numbers. Any time a numeric-looking key passes through a factor, the
double conversion is the safe route.

## Near-matches and typos

Sometimes keys are close but not identical. These are genuine
mismatches, untouched by whitespace and case repairs, that
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
near-matches; `GZM-300` and `GZM-301` sit at edit distance 1. Here is a
clearer example with multiple near-matches:

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
within edit distance 2. `"Williams"` matches exactly. The search has
deliberate limits: it considers pairs within edit distance 2, skips keys
shorter than 3 characters, and scans at most the first 50 unmatched keys
against 100 candidates. On large tables the near-match list is therefore
a sample of the problem, a prompt to look further along the same lines.

There is no automated fix here since joinspy cannot know which side is
correct, but the near-match list gives a concrete starting point for
building a lookup table. Once we have decided which side is
authoritative, the corrections belong in a small recode table stored
with the pipeline, so the same typo never needs re-diagnosing. Typos
like these usually trace back to hand-entered data; where the key is
supposed to be machine-generated, a near-match is worth treating as a
symptom of two systems generating IDs independently.

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

Every offending row comes back with a `.n_duplicates` count attached.
`keep = "first"` or `keep = "last"` reduce the output to one row per
key, which doubles as a quick deduplication candidate:

``` r

key_duplicates(addresses, by = "customer_id", keep = "first")
#>   customer_id address .n_duplicates
#> 2           2      LA             2
```

If each customer should have one address, we deduplicate first. If we
genuinely need all combinations, the multiplication is correct – we just
need to know it will happen. Duplicates often mean the right table is a
different entity than assumed: an address *history* where we expected a
current-address table. The fix is then a data-model decision, picking
the latest row, aggregating, or accepting the multiplication
deliberately. Whichever we choose, encoding it as a
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
expectation (shown below) catches the silent regression when next
month’s extract grows a second row per customer.

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

By default it raises the alarm when the result would exceed 10 times the
larger input; the `threshold` argument adjusts that cut-off.

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

Removal is right when missing IDs are noise. When they carry meaning,
say unattributed orders that should collect under a single placeholder
customer, the sentinel route makes them joinable. We replace the NA with
an impossible ID on both sides:

``` r

orders_s <- orders
customers_s <- customers
orders_s$customer_id[is.na(orders_s$customer_id)] <- -1
customers_s$customer_id[is.na(customers_s$customer_id)] <- -1

join_spy(orders_s, customers_s, by = "customer_id")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: customer_id
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 4 Unique keys: 3 Duplicate keys: 1 NA keys: 0
#> Right table: Rows: 4 Unique keys: 4 Duplicate keys: 0 NA keys: 0
#> 
#> ── Match Analysis ──
#> 
#> Keys in both: 3
#> Keys only in left: 0
#> Keys only in right: 1
#> Match rate (left): "100%"
#> 
#> ── Issues Detected ──
#> 
#> ! Left table has 1 duplicate key(s) affecting 2 rows - may cause row multiplication
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 4
#> left_join: 4
#> right_join: 5
#> full_join: 5
```

The NA warnings are gone and the match rate is 100%. The report now
warns about something new: the sentinel appears twice on the left, so it
is a duplicate key, and both formerly missing orders will attach to the
same `"Unknown"` row:

``` r

merge(orders_s, customers_s, by = "customer_id", all.x = TRUE)
#>   customer_id amount    name
#> 1          -1    200 Unknown
#> 2          -1    400 Unknown
#> 3           1    100   Alice
#> 4           3    300   Carol
```

A sentinel makes missing keys equal to each other, which is the behavior
we asked for, so the duplication here is expected. The value must be
impossible as a real ID: `-1` works for positive integer keys, something
like `"__missing__"` for character keys. Both sides need the
replacement, since a sentinel on one side and an NA on the other still
never match. NA keys usually arrive from earlier outer joins or from
incomplete entry, and
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
lists them as one of its standard explanations, so a post-join row-count
surprise often traces back to this section.

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

The repair direction matters: converting the numeric side to character,
as above, is lossless. Going the other way destroys any key with leading
zeros:

``` r

ids <- c("007", "042")
as.character(as.numeric(ids))
#> [1] "7"  "42"
```

`"007"` comes back as `"7"`, a different key, and any non-numeric ID in
the column becomes NA outright. Type drift between extracts is common
with type-sniffing readers: a column of all-digit IDs imports as numeric
until the first alphanumeric ID appears, at which point the same column
imports as character. Pinning the type at import (`colClasses` in base
R, `col_types` in readr) removes the drift at its source.

## Numeric keys with floating-point noise

Numeric keys produced by arithmetic carry floating-point noise. Three
depths built by accumulating 0.1 look identical to hand-typed values
when printed, and the third one is different:

``` r

readings <- data.frame(depth = cumsum(rep(0.1, 3)), oxygen = c(8.1, 7.4, 6.9))
layers <- data.frame(
  depth = c(0.1, 0.2, 0.3),
  layer = c("surface", "mid", "bottom")
)

print(readings$depth, digits = 17)
#> [1] 0.10000000000000001 0.20000000000000001 0.30000000000000004
readings$depth == layers$depth
#> [1]  TRUE  TRUE FALSE
```

The accumulated third value is 0.30000000000000004, so the comparison
with 0.3 fails.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
warns about the key type and the match analysis shows the damage:

``` r

join_spy(readings, layers, by = "depth")
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: depth
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
#> ! Floating-point key values may not match exactly due to precision
#> ! Floating-point key values may not match exactly due to precision
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 3
#> left_join: 3
#> right_join: 3
#> full_join: 3
```

The match analysis reports 2 keys in both tables, with one orphan on
each side: the two versions of 0.3 that refuse to be equal. The
floating-point warning fires whenever a key column holds non-integer
doubles, on both tables here, because any such key can fail this way.
Pinpointing which values differ by an epsilon is outside joinspy’s
string checks; that part is on us, and the standard fix is to remove the
noise before joining:

``` r

readings$depth <- round(readings$depth, 6)
all(readings$depth %in% layers$depth)
#> [1] TRUE
```

Rounding to a precision coarser than the noise and finer than the data
restores exact equality. A sturdier design avoids fractional keys
entirely. Store depth in centimeters as an integer, or format it to a
fixed-width string, and this failure mode does not come back. Fractional
keys usually appear when a measured quantity gets promoted into an
identifier; an explicit ID column upstream removes the temptation.

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
#> ℹ Detected cardinality: "n:m"
#> Left duplicates: 2 key(s)
#> Right duplicates: 2 key(s)
```

If we expected a one-to-many relationship,
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
will stop us before the explosion happens:

``` r

join_strict(items, payments, by = "order_id", type = "left", expect = "1:n")
#> Error in `join_strict()`:
#> ! Cardinality violation: expected "1:n" but found "n:m".
#> ℹ Left duplicates: 2, right duplicates: 2.
```

The error arrives before any rows are produced, which matters when the
explosion would have been the million-row kind. Many-to-many joins that
are intentional, such as enumerating all item-payment pairs for
reconciliation, are better written with the expectation stated:
`expect = "n:m"` passes every cardinality and documents that the
expansion is deliberate. The `*_join_spy()` wrappers report the
predicted row count for the same reason, so a join expected to preserve
row counts announces itself when it triples them instead. Explosions
almost always enter a pipeline through a table that quietly gained a
second granularity, an `order_id` table that became an `order_id` x
`payment_attempt` table, and the cardinality check is the cheapest way
to notice.

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

Format mismatches like this are structural: the two systems never shared
an ID scheme, so joinspy can report the zero overlap and the absence of
string issues, and that combination is itself the diagnosis. The
[`gsub()`](https://rdrr.io/r/base/grep.html) extraction works when one
format embeds the other. Failing that, somebody owns a mapping table,
and the join goes through it. The named `by` in the final
[`key_check()`](https://gillescolling.com/joinspy/reference/key_check.md)
call joins our derived `user_num` column against system B’s `user_id`
without renaming anything; the next section covers that syntax.

## Differently named key columns

Tables rarely agree on what the key column is called: `patient_id` in
the admissions extract is `mrn` in the registry. A named `by` vector
maps left names to right names, and every joinspy function accepts it:

``` r

admissions <- data.frame(
  patient_id = c("P-01 ", "P-02", "P-03"),
  ward = c("A", "B", "B"),
  stringsAsFactors = FALSE
)

registry <- data.frame(
  mrn = c("P-01", "P-02", "P-04"),
  dob = c("1980-03-02", "1975-11-19", "1990-07-30"),
  stringsAsFactors = FALSE
)

join_spy(admissions, registry, by = c("patient_id" = "mrn"))
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: patient_id = mrn
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
#> ! Left column 'patient_id' has 1 value(s) with leading/trailing whitespace
#> ℹ 6 near-match(es) found (e.g., 'P-01 ' ~ 'P-01', 'P-03' ~ 'P-01', 'P-03' ~ 'P-02') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 1
#> left_join: 3
#> right_join: 3
#> full_join: 5
```

The header line shows the mapping (`patient_id = mrn`), and the
diagnostics run as usual: the whitespace warning points at `patient_id`,
and the near-match list pairs `'P-01 '` with `'P-01'`. Repairs and joins
take the same vector, with
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
fixing `patient_id` on the left and `mrn` on the right:

``` r

fixed <- join_repair(admissions, registry, by = c("patient_id" = "mrn"))
#> ✔ Repaired 1 value(s)
left_join_spy(fixed$x, fixed$y, by = c("patient_id" = "mrn"), verbose = FALSE)
#>   patient_id ward        dob
#> 1       P-01    A 1980-03-02
#> 2       P-02    B 1975-11-19
#> 3       P-03    B       <NA>
```

The result keeps the left table’s column name, `patient_id`, and the
unmatched `P-03` carries an NA date of birth. Renaming columns before a
join is the common workaround, and it tends to decay as scripts grow,
with the rename and the join drifting apart until one of them changes
alone. Passing the mapping straight to `by` keeps the two halves of the
decision in one place.

## Troubleshooting workflow

The sections above each handle one failure in isolation. On a real join
we usually do not know which failure we have, so this is the order we
check in, walked through on a pair of tables that carries several
problems at once:

``` r

shipments <- data.frame(
  order_ref = c("ORD-1 ", "ORD-2", "ORD-2", "ORD-3", NA),
  qty = c(10, 25, 5, 12, 7),
  stringsAsFactors = FALSE
)

invoices <- data.frame(
  order_ref = c("ORD-1", "ORD-2", "ORD-4"),
  total = c(99, 250, 80),
  stringsAsFactors = FALSE
)
```

**Step 1: run
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
and read it top to bottom.** The match rate and the issue list classify
the problem before we attempt any fix. For large tables, `sample = 1000`
runs the same diagnostics on a random subset first.

``` r

report <- join_spy(shipments, invoices, by = "order_ref")
report
#> 
#> ── Join Diagnostic Report ──────────────────────────────────────────────────────
#> Join columns: order_ref
#> 
#> ── Table Summary ──
#> 
#> Left table: Rows: 5 Unique keys: 3 Duplicate keys: 1 NA keys: 1
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
#> ! Left table has 1 duplicate key(s) affecting 2 rows - may cause row multiplication
#> ! Left table has 1 NA key(s) - these will not match
#> ! Left column 'order_ref' has 1 value(s) with leading/trailing whitespace
#> ℹ 6 near-match(es) found (e.g., 'ORD-1 ' ~ 'ORD-1', 'ORD-3' ~ 'ORD-1', 'ORD-3' ~ 'ORD-2') - possible typos?
#> 
#> ── Expected Row Counts ──
#> 
#> inner_join: 2
#> left_join: 5
#> right_join: 4
#> full_join: 7
```

One report, four findings: a duplicate key, an NA key, a whitespace
problem, and a clutch of near-matches. Each outcome routes to a step
below:

1.  Whitespace, case, encoding, or empty-string issues: repair the
    strings (step 2).

2.  Duplicate keys, or expected row counts above the left table’s row
    count: inspect the duplicates (step 3).

3.  NA keys: decide what missing means (step 4).

4.  A type mismatch: align the types (step 5).

5.  Near-matches on otherwise clean keys: build a recode table (the
    near-match section above).

6.  A 0% match rate with no string issues: a format mismatch; extract a
    common key or find the mapping table (the no-matches section above).

**Step 2: repair the strings.**
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
covers whitespace, case, invisible characters, and empty strings in one
call; `suggest_repairs(report)` prints the equivalent base R when the
fix has to live elsewhere.

``` r

shipments_repaired <- join_repair(shipments, by = "order_ref")
#> ✔ Repaired 1 value(s)
```

**Step 3: inspect the duplicates.**
[`key_duplicates()`](https://gillescolling.com/joinspy/reference/key_duplicates.md)
shows the rows,
[`detect_cardinality()`](https://gillescolling.com/joinspy/reference/detect_cardinality.md)
names the relationship, and
[`check_cartesian()`](https://gillescolling.com/joinspy/reference/check_cartesian.md)
bounds the blow-up for the worst keys.

``` r

key_duplicates(shipments_repaired, by = "order_ref")
#>   order_ref qty .n_duplicates
#> 2     ORD-2  25             2
#> 3     ORD-2   5             2
detect_cardinality(shipments_repaired, invoices, by = "order_ref")
#> ℹ Detected cardinality: "n:1"
#> Left duplicates: 1 key(s)
```

`ORD-2` appears twice on the left, so the relationship is `n:1`. If two
shipments per order is the real shape of the data, we keep it and state
the expectation in step 6. If it is an accident, we deduplicate or
aggregate here.

**Step 4: decide what NA keys mean.** Dropping loses the 7-unit shipment
with no reference; the sentinel route from the NA section keeps it under
a placeholder. Here we drop:

``` r

shipments_repaired <- shipments_repaired[!is.na(shipments_repaired$order_ref), ]
```

**Step 5: align types.** Nothing to fix in this example; when the report
shows a numeric column joining a character column, we convert toward
character (the lossless direction) or pin the types at import.

**Step 6: join with the expectation enforced.**
[`join_strict()`](https://gillescolling.com/joinspy/reference/join_strict.md)
performs the join only if the cardinality matches what we declared, so
the data model decision from step 3 becomes executable:

``` r

result <- join_strict(shipments_repaired, invoices, by = "order_ref",
                      type = "left", expect = "n:1")
result
#>   order_ref qty total
#> 1     ORD-1  10    99
#> 2     ORD-2  25   250
#> 3     ORD-2   5   250
#> 4     ORD-3  12    NA
```

**Step 7: audit the result.**
[`join_explain()`](https://gillescolling.com/joinspy/reference/join_explain.md)
accounts for the difference between input and output row counts after
the fact:

``` r

join_explain(result, shipments_repaired, invoices,
             by = "order_ref", type = "left")
#> 
#> ── Join Explanation ────────────────────────────────────────────────────────────
#> 
#> ── Row Counts ──
#> 
#> Left table (x): 4 rows
#> Right table (y): 3 rows
#> Result: 4 rows
#> ✔ Result has same row count as left table
#> 
#> ── Why the row count changed ──
#> 
#> ℹ Left table has 1 duplicate key(s) - each match creates multiple rows
#> ℹ 1 left key(s) have no match in right table
```

The row count is unchanged at 4, and the explanation still lists the two
forces that could have moved it: the duplicate `ORD-2` and the unmatched
`ORD-3`. On a larger join those same lines say where unexpected rows
came from.
[`join_diff()`](https://gillescolling.com/joinspy/reference/join_diff.md)
offers the same comparison oriented around column changes.

**Step 8: leave a trail.** In production pipelines,
[`set_log_file()`](https://gillescolling.com/joinspy/reference/set_log_file.md)
routes every subsequent `*_join_spy()` report to a file, which is how we
debug a join that went wrong last Tuesday:

``` r

log_file <- tempfile(fileext = ".log")
set_log_file(log_file)
#> ℹ Automatic logging enabled: C:\Users\GILLES~1\AppData\Local\Temp\Rtmp4OayX0\file23f83fab381c.log
audited <- left_join_spy(shipments_repaired, invoices,
                         by = "order_ref", .quiet = TRUE)
set_log_file(NULL)
#> ℹ Automatic logging disabled
readLines(log_file)[2:8]
#> [1] "Logged: 2026-06-13 00:54:01"                                 
#> [2] "------------------------------------------------------------"
#> [3] "Join Key: order_ref"                                         
#> [4] ""                                                            
#> [5] "Left Table (x):"                                             
#> [6] "  Rows: 4"                                                   
#> [7] "  Unique keys: 3"
```

With `.quiet = TRUE` the join runs silently and the report still lands
in the log;
[`last_report()`](https://gillescolling.com/joinspy/reference/last_report.md)
retrieves it in-session. For one-off snapshots,
[`log_report()`](https://gillescolling.com/joinspy/reference/log_report.md)
writes a single report, and a `.json` or `.rds` extension switches the
format for machine consumption.

**Step 9: for multi-join pipelines, check the whole chain.**
[`analyze_join_chain()`](https://gillescolling.com/joinspy/reference/analyze_join_chain.md)
runs the step 1 diagnostic at every link and reports where the first
problem enters:

``` r

orders <- data.frame(order_id = 1:3, customer_id = c(1, 2, 2))
customers <- data.frame(customer_id = 1:3, region_id = c(1, 1, 2))
regions <- data.frame(region_id = 1:2, name = c("North", "South"))

analyze_join_chain(
  tables = list(orders = orders, customers = customers, regions = regions),
  joins = list(
    list(left = "orders", right = "customers", by = "customer_id"),
    list(left = "result", right = "regions", by = "region_id")
  )
)
#> 
#> ── Join Chain Analysis ─────────────────────────────────────────────────────────
#> 
#> ── Step 1: orders + customers ──
#> 
#> Left: 3 rows
#> Right: 3 rows
#> Match rate: 100%
#> Expected result: 3 rows (left join)
#> ! 1 issue(s) detected
#> 
#> ── Step 2: result + regions ──
#> 
#> Left: 3 rows
#> Right: 2 rows
#> Match rate: 100%
#> Expected result: 3 rows (left join)
#> ! 1 issue(s) detected
#> 
#> ── Chain Summary ──
#> 
#> ! Total issues across chain: 2
```

Each step gets its own match rate and issue count, with `"result"`
referring to the output of the previous join, so the first bad link in a
five-table pipeline is visible without bisecting by hand.

## See Also

- [`vignette("quickstart")`](https://gillescolling.com/joinspy/articles/quickstart.md)
  for a quick introduction to joinspy

- [`?join_spy`](https://gillescolling.com/joinspy/reference/join_spy.md),
  [`?join_repair`](https://gillescolling.com/joinspy/reference/join_repair.md),
  [`?key_check`](https://gillescolling.com/joinspy/reference/key_check.md),
  [`?join_strict`](https://gillescolling.com/joinspy/reference/join_strict.md)

- [`?check_cartesian`](https://gillescolling.com/joinspy/reference/check_cartesian.md),
  [`?detect_cardinality`](https://gillescolling.com/joinspy/reference/detect_cardinality.md),
  [`?join_explain`](https://gillescolling.com/joinspy/reference/join_explain.md),
  [`?suggest_repairs`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
