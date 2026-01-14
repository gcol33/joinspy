# =============================================================================
# Tests for Phase 2 Enhanced Detection
# =============================================================================

test_that(".detect_type_mismatch identifies character/factor mismatch", {
  x_col <- c("A", "B", "C")
  y_col <- factor(c("A", "B", "C"))

  result <- joinspy:::.detect_type_mismatch(x_col, y_col, "x_id", "y_id")

  expect_true(result$has_issues)
  expect_true(any(sapply(result$issues, function(i) i$type == "type_mismatch")))
})

test_that(".detect_type_mismatch identifies numeric/character mismatch", {
  x_col <- c(1, 2, 3)
  y_col <- c("1", "2", "3")

  result <- joinspy:::.detect_type_mismatch(x_col, y_col, "x_id", "y_id")

  expect_true(result$has_issues)
  expect_true(any(sapply(result$issues, function(i) i$severity == "warning")))
})

test_that(".detect_factor_mismatch finds level differences", {
  x_col <- factor(c("A", "B"), levels = c("A", "B", "C"))
  y_col <- factor(c("B", "C"), levels = c("B", "C", "D"))

  result <- joinspy:::.detect_factor_mismatch(x_col, y_col, "x_id", "y_id")

  expect_true(result$has_issues)
})

test_that(".detect_empty_strings finds empty strings", {
  x <- c("A", "", "C", "")

  result <- joinspy:::.detect_empty_strings(x)

  expect_true(result$has_issues)
  expect_equal(result$n_empty, 2)
})

test_that(".detect_numeric_precision warns on floating point keys", {
  x <- c(1.5, 2.7, 3.14159)

  result <- joinspy:::.detect_numeric_precision(x)

  expect_true(result$has_issues)
})

test_that(".detect_near_matches finds similar keys", {
  x_keys <- c("Smith", "Johnson", "Williams")
  y_keys <- c("Smth", "Johnsen", "Wilson")  # Typos

  result <- joinspy:::.detect_near_matches(x_keys, y_keys)

  expect_true(result$has_issues)
  expect_true(nrow(result$near_matches) > 0)
})

test_that(".analyze_multicolumn_keys analyzes composite keys", {
  x <- data.frame(a = 1:3, b = c("x", "y", "z"))
  y <- data.frame(a = 1:3, b = c("x", "y", "w"))

  result <- joinspy:::.analyze_multicolumn_keys(x, y, c("a", "b"), c("a", "b"))

  expect_true(result$is_multicolumn)
  expect_true("a" %in% names(result$column_analysis))
  expect_true("b" %in% names(result$column_analysis))
})

test_that("join_spy includes Phase 2 enhanced detection", {
  x <- data.frame(
    id = c("ABC", "", "DEF"),
    val = 1:3,
    stringsAsFactors = FALSE
  )
  y <- data.frame(
    id = c("abc", "GHI"),
    name = c("a", "g"),
    stringsAsFactors = FALSE
  )

  report <- join_spy(x, y, by = "id")

  # Should detect case mismatch
  has_case <- any(sapply(report$issues, function(i) i$type == "case_mismatch"))
  expect_true(has_case)

  # Should detect empty string
  has_empty <- any(sapply(report$issues, function(i) i$type == "empty_string"))
  expect_true(has_empty)
})

test_that("join_spy detects near-matches", {
  x <- data.frame(
    name = c("Michael", "Jennifer", "Christopher"),
    val = 1:3,
    stringsAsFactors = FALSE
  )
  y <- data.frame(
    name = c("Micheal", "Jenifer", "Chris"),  # Typos
    id = 1:3,
    stringsAsFactors = FALSE
  )

  report <- join_spy(x, y, by = "name")

  has_near <- any(sapply(report$issues, function(i) i$type == "near_match"))
  expect_true(has_near)
})
