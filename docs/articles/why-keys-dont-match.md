# Why Your Keys Don't Match

A join runs without error but the row count is wrong – fewer rows than
expected, or more. The columns look fine. The key values look identical
in the console.

R’s [`merge()`](https://rdrr.io/r/base/merge.html) and dplyr’s
`*_join()` compare key values byte-for-byte. When keys fail to match,
they are genuinely different at the byte level: a trailing space, a case
mismatch, or a zero-width Unicode character that occupies no screen
width.

This vignette walks through five scenarios where joins fail for
string-level reasons that resist casual inspection. The data is
synthetic; the patterns come from real pipelines.

## Scenario 1: The Excel Export

A retail analytics team receives monthly sales data from a distribution
partner as a CSV exported from Excel. They join it against their
internal customer database on `customer_id`. For two quarters,
everything works. Then one month, 30% of the sales records stop
matching. Nobody changed the code or the customer database. The
partner’s IDs are all present in the internal system – or so it appears.

``` r

partner_sales <- data.frame(
  customer_id = c("CUST-1001", "CUST-1002 ", "CUST-1003",
                  " CUST-1004", "CUST-1005 ", "CUST-1006"),
  amount = c(2500, 1800, 3200, 950, 4100, 1600),
  stringsAsFactors = FALSE
)

internal_db <- data.frame(
  customer_id = c("CUST-1001", "CUST-1002", "CUST-1003",
                  "CUST-1004", "CUST-1005", "CUST-1006", "CUST-1007"),
  region = c("West", "East", "West", "South", "East", "North", "West"),
  stringsAsFactors = FALSE
)
```

Nothing in [`str()`](https://rdrr.io/r/utils/str.html) or
[`print()`](https://rdrr.io/r/base/print.html) reveals the issue –
trailing spaces are invisible in console output.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
catches it:

``` r

report <- join_spy(partner_sales, internal_db, by = "customer_id")
```

Three of the six partner IDs carry whitespace. `"CUST-1002 "` is a
different string from `"CUST-1002"` as far as R is concerned.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
trims both tables at once:

``` r

repaired <- join_repair(partner_sales, internal_db, by = "customer_id")
#> ✔ Repaired 3 value(s)
partner_fixed <- repaired$x
internal_fixed <- repaired$y
```

We can verify the repair worked:

``` r

key_check(partner_fixed, internal_fixed, by = "customer_id")
#> ✔ Key check passed: no issues detected
```

And now the join gives us what we expected:

``` r

result <- merge(partner_fixed, internal_fixed, by = "customer_id")
nrow(result)
#> [1] 6
```

The root cause was an Excel `CONCATENATE` formula that preserved
trailing spaces from a variable-width source column. Excel renders
`"CUST-1002"` and `"CUST-1002 "` identically, so nobody noticed.
Trailing whitespace is the single most common join failure we see in
practice.

## Scenario 2: Two Databases, Two Conventions

A SaaS company wants to join CRM profiles to clickstream events for a
churn analysis. The CRM stores email addresses in uppercase (a database
migration decision from the late 1990s). The web app stores them in
lowercase. Both systems are internally consistent.

``` r

crm_profiles <- data.frame(
  email = c("ALICE@ACME.COM", "BOB@ACME.COM", "CAROL@ACME.COM",
            "DAVE@ACME.COM", "EVE@ACME.COM"),
  plan = c("enterprise", "starter", "pro", "enterprise", "starter"),
  stringsAsFactors = FALSE
)

click_events <- data.frame(
  email = c("alice@acme.com", "bob@acme.com", "carol@acme.com",
            "dave@acme.com", "frank@acme.com"),
  page_views = c(47, 12, 89, 33, 5),
  stringsAsFactors = FALSE
)
```

An inner join returns zero rows. R’s string comparison is
case-sensitive, so every key pair fails.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
flags the situation before the join:

``` r

report <- join_spy(crm_profiles, click_events, by = "email")
```

[`suggest_repairs()`](https://gillescolling.com/joinspy/reference/suggest_repairs.md)
generates the fix:

``` r

suggest_repairs(report)
#> 
#> ── Suggested Repairs ───────────────────────────────────────────────────────────
#> # Standardize case:
#> x$email <- tolower(x$email)
#> y$email <- tolower(y$email)
```

Or we can use
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
directly, specifying case standardization:

``` r

repaired <- join_repair(
  crm_profiles, click_events,
  by = "email",
  standardize_case = "lower"
)
#> ✔ Repaired 5 value(s)
```

After lowercasing both sides, the inner join returns four matched rows
(everyone except Eve, who has no click data, and Frank, who is not in
the CRM):

``` r

result <- merge(repaired$x, repaired$y, by = "email")
nrow(result)
#> [1] 4
result
#>            email       plan page_views
#> 1 alice@acme.com enterprise         47
#> 2   bob@acme.com    starter         12
#> 3 carol@acme.com        pro         89
#> 4  dave@acme.com enterprise         33
```

Email addresses are case-insensitive by RFC 5321, so lowercasing is the
right normalization here. For other identifier types (product codes,
country abbreviations), `"upper"` may be more appropriate.

## Scenario 3: The PDF Copy-Paste

A public health researcher compiles data from multiple sources for a
systematic review. A few studies published supplementary tables only as
PDF, so she copies the table from the PDF viewer, pastes into a
spreadsheet, cleans up the columns, and reads the CSV into R. The data
looks perfect – every country name is spelled correctly. But half the
countries fail to match a reference population table.

``` r

# Simulating PDF copy-paste artifacts:
# \u00A0 is non-breaking space, \u200B is zero-width space
pdf_data <- data.frame(
  country = c("Brazil", "India\u200B", "Germany",
              "Japan\u00A0", "Canada", "France\u200B"),
  prevalence = c(12.3, 8.7, 5.1, 3.9, 6.2, 4.8),
  stringsAsFactors = FALSE
)

reference <- data.frame(
  country = c("Brazil", "India", "Germany", "Japan",
              "Canada", "France", "Italy"),
  population_m = c(214, 1408, 84, 125, 38, 68, 59),
  stringsAsFactors = FALSE
)
```

Printing the PDF data shows nothing wrong:

``` r

pdf_data$country
#> [1] "Brazil"  "India​"   "Germany" "Japan "  "Canada"  "France​"
```

The zero-width space after “India” and “France” occupies zero pixels.
The non-breaking space after “Japan” renders like a regular space but is
U+00A0, not U+0020 – [`trimws()`](https://rdrr.io/r/base/trimws.html)
will not always remove it. The merge reflects this:

``` r

nrow(merge(pdf_data, reference, by = "country"))
#> [1] 3
```

Three of six countries match.
[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
detects the invisible characters:

``` r

report <- join_spy(pdf_data, reference, by = "country")
```

``` r

repaired <- join_repair(pdf_data, reference, by = "country")
#> ✔ Repaired 3 value(s)
nrow(merge(repaired$x, repaired$y, by = "country"))
#> [1] 6
```

Six matches. PDF copy-paste is the most common source of these
artifacts, but web scraping, OCR output, and legacy mainframe exports
can produce them too. One useful debugging trick outside of joinspy:
`nchar("India\u200B")` returns 6, not 5. But that requires already
suspecting the problem.

## Scenario 4: The Slowly Growing Mismatch

An e-commerce pipeline joins transaction records to a product catalogue.
The pipeline ran cleanly for months, then match rates started drifting:
99% in January, 97% in February, 94% in March. Nobody noticed until
finance flagged a margin discrepancy in April.

The code had not changed. A new data entry clerk had joined the
warehouse team in December. The canonical product code format was
`"WDG-100"` – uppercase prefix, dash, three-digit suffix. The new clerk
sometimes omitted the dash, sometimes typed lowercase. The warehouse
system did fuzzy matching internally, so it accepted the codes. The ETL
join did not.

``` r

# Product catalogue (canonical format)
catalogue <- data.frame(
  product_code = c("WDG-100", "WDG-101", "WDG-102",
                   "WDG-103", "WDG-104", "WDG-105"),
  product_name = c("Widget A", "Widget B", "Widget C",
                   "Widget D", "Widget E", "Widget F"),
  margin = c(0.35, 0.28, 0.42, 0.31, 0.39, 0.25),
  stringsAsFactors = FALSE
)

# Recent transactions (mix of old and new clerk entries)
transactions <- data.frame(
  product_code = c("WDG-100", "WDG-101", "WDG102",
                   "wdg-103", "WDG-104", "wdg105",
                   "WDG-100", "WDG103"),
  quantity = c(5, 3, 7, 2, 4, 6, 1, 8),
  stringsAsFactors = FALSE
)
```

Some codes match and some do not, which makes partial failures harder to
spot than complete ones.

``` r

report <- join_spy(transactions, catalogue, by = "product_code")
```

Here is where this scenario differs from the previous ones.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
can fix the case issue, but it cannot insert the missing dashes – that
requires domain knowledge about the code format.

We can do a dry run to see what
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
would fix:

``` r

join_repair(transactions, catalogue,
            by = "product_code",
            standardize_case = "upper",
            dry_run = TRUE)
#> 
#> ── Repair Preview (Dry Run) ────────────────────────────────────────────────────
#> 
#> ── Left table (x) ──
#> 
#> ℹ product_code: upper case (2)
```

After applying the mechanical fixes:

``` r

repaired <- join_repair(transactions, catalogue,
                        by = "product_code",
                        standardize_case = "upper")
#> ✔ Repaired 2 value(s)
```

The case issues are resolved, but the missing dashes remain. A manual
transformation handles those:

``` r

# Manual fix: insert dash if missing in product codes matching the pattern
fix_codes <- function(codes) {
  gsub("^([A-Z]{3})(\\d)", "\\1-\\2", codes)
}
repaired$x$product_code <- fix_codes(repaired$x$product_code)
```

``` r

result <- merge(repaired$x, repaired$y, by = "product_code")
nrow(result)
#> [1] 8
```

All eight transactions match.
[`join_repair()`](https://gillescolling.com/joinspy/reference/join_repair.md)
handles context-free transformations (trimming, case normalization,
stripping invisible characters). Inserting a dash into `"WDG102"`
requires knowing the canonical format – that fix has to come from
someone who understands the data.

## Scenario 5: Compound Keys

Two government datasets need to be linked: regional economic indicators
and regional population estimates, keyed on region and year. The year
column is numeric and matches without trouble. The region column has a
whitespace problem that affects only some records.

``` r

economics <- data.frame(
  region = c("North America", "Europe", "Asia Pacific ",
             "North America", "Europe", "Asia Pacific "),
  year = c(2022, 2022, 2022, 2023, 2023, 2023),
  gdp_growth = c(2.1, 1.8, 4.2, 1.9, 0.9, 3.8),
  stringsAsFactors = FALSE
)

population <- data.frame(
  region = c("North America", "Europe", "Asia Pacific",
             "North America", "Europe", "Asia Pacific"),
  year = c(2022, 2022, 2022, 2023, 2023, 2023),
  pop_millions = c(580, 450, 4300, 585, 448, 4350),
  stringsAsFactors = FALSE
)
```

In a compound key join, both columns must match. The year column is fine
everywhere, but `"Asia Pacific "` with a trailing space will not match
`"Asia Pacific"`.

``` r

merged <- merge(economics, population, by = c("region", "year"))
nrow(merged)
#> [1] 4
```

Four rows instead of six. North America and Europe match; Asia Pacific
does not, because of the trailing space.

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
pinpoints which column in the compound key has the problem:

``` r

report <- join_spy(economics, population, by = c("region", "year"))
```

``` r

repaired <- join_repair(economics, population, by = c("region", "year"))
#> ✔ Repaired 2 value(s)
result <- merge(repaired$x, repaired$y, by = c("region", "year"))
nrow(result)
#> [1] 6
```

Six rows. With compound keys, a string issue in any single column is
enough to break the match. The more columns in the key, the more places
a byte-level discrepancy can occur.

## The Pattern

These five scenarios share three properties. The data looks correct to
standard inspection tools – [`str()`](https://rdrr.io/r/utils/str.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`print()`](https://rdrr.io/r/base/print.html) all render the values
identically. R returns fewer (or more) rows without a warning, because
the key values genuinely differ at the byte level. And the fix is
mechanical once the cause is known – trimming, lowercasing, or stripping
invisible Unicode are all one-line operations.

[`join_spy()`](https://gillescolling.com/joinspy/reference/join_spy.md)
surfaces the cause directly, which is especially useful with data from
external sources, manual entry, PDF extraction, or cross-system
integrations.
