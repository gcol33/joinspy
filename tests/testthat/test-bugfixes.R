# =============================================================================
# Regression tests for fixed bugs
# =============================================================================

test_that("log_report records duplicate key counts in text output (#1)", {
  x <- data.frame(id = c(1, 2, 2, 3), val = 1:4)
  y <- data.frame(id = c(1, 2, 3), name = c("a", "b", "c"))
  report <- join_spy(x, y, by = "id")
  expect_equal(report$x_summary$n_duplicates, 1)

  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  log_report(report, tmp, timestamp = FALSE)

  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, "Duplicated keys: 1")
})

test_that("log_report records duplicate key counts in JSON output (#1)", {
  x <- data.frame(id = c(1, 2, 2, 3), val = 1:4)
  y <- data.frame(id = c(1, 2, 3), name = c("a", "b", "c"))
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  log_report(report, tmp)

  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, '"n_duplicates": 1')
})

test_that("composite keys are NA when any component is NA (#3)", {
  x <- data.frame(
    k1 = c("a", "a", "b"),
    k2 = c("x", "y", NA),
    val = 1:3,
    stringsAsFactors = FALSE
  )
  s <- joinspy:::.summarize_keys(x, c("k1", "k2"))
  expect_equal(s$n_na, 1)
})

test_that("composite key NA rows do not match across tables (#3)", {
  x <- data.frame(k1 = c("a", "b"), k2 = c("x", NA), stringsAsFactors = FALSE)
  y <- data.frame(k1 = c("a", "b"), k2 = c("x", NA),
                  name = c("A", "B"), stringsAsFactors = FALSE)
  # Only (a, x) matches; the (b, NA) rows must not match each other
  pred <- joinspy:::.predict_row_counts(x, y, c("k1", "k2"))
  expect_equal(pred$inner, 1)
})

test_that("predicted row counts stay numeric, not coerced to integer (#4)", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = c(1, 2), name = c("a", "b"))
  pred <- joinspy:::.predict_row_counts(x, y, "id")
  expect_type(pred$inner, "double")
  expect_type(pred$full, "double")
})

test_that("printing a report with brace-containing column names is safe (#5)", {
  x <- data.frame(`a{b}` = c("1 ", "2"), check.names = FALSE,
                  stringsAsFactors = FALSE)
  y <- data.frame(`a{b}` = c("1", "3"), check.names = FALSE,
                  stringsAsFactors = FALSE)
  report <- join_spy(x, y, by = "a{b}")
  expect_no_error(capture.output(print(report)))
})

test_that("suggest_repairs produces valid code for non-syntactic names (#6)", {
  x <- data.frame(`order id` = c("A ", "B"), check.names = FALSE,
                  stringsAsFactors = FALSE)
  y <- data.frame(`order id` = c("A", "B"), check.names = FALSE,
                  stringsAsFactors = FALSE)
  report <- join_spy(x, y, by = "order id")
  sugg <- suppressMessages(suggest_repairs(report))

  expect_true(any(grepl('[["order id"]]', sugg, fixed = TRUE)))
  for (s in sugg) {
    expect_silent(parse(text = s))
  }
})

test_that("package works without base R %||% (import is present) (#2)", {
  # %||% must resolve from the package namespace, not depend on base R >= 4.4
  expect_true(exists("%||%", envir = asNamespace("joinspy")))
})
