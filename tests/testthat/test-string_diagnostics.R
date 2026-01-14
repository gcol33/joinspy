# =============================================================================
# Tests for string diagnostic utilities
# =============================================================================

# Note: These test internal functions using :::

test_that(".detect_whitespace finds leading whitespace", {
  x <- c(" A", "B", "C")

  result <- joinspy:::.detect_whitespace(x)

  expect_true(result$has_issues)
  expect_equal(result$leading, 1)
  expect_equal(length(result$trailing), 0)
})

test_that(".detect_whitespace finds trailing whitespace", {
  x <- c("A", "B ", "C")

  result <- joinspy:::.detect_whitespace(x)

  expect_true(result$has_issues)
  expect_equal(result$trailing, 2)
  expect_equal(length(result$leading), 0)
})

test_that(".detect_whitespace returns no issues for clean strings", {
  x <- c("A", "B", "C")

  result <- joinspy:::.detect_whitespace(x)

  expect_false(result$has_issues)
})

test_that(".detect_whitespace handles non-character input", {
  x <- 1:5

  result <- joinspy:::.detect_whitespace(x)

  expect_false(result$has_issues)
})

test_that(".detect_case_mismatch finds case differences", {
  x <- c("ABC", "def")
  y <- c("abc", "DEF")

  result <- joinspy:::.detect_case_mismatch(x, y)

  expect_true(result$has_issues)
  expect_equal(nrow(result$mismatches), 2)
})

test_that(".detect_case_mismatch returns no issues when cases match", {
  x <- c("ABC", "DEF")
  y <- c("ABC", "DEF")

  result <- joinspy:::.detect_case_mismatch(x, y)

  expect_false(result$has_issues)
})

test_that(".detect_case_mismatch handles non-character input", {
  x <- 1:3
  y <- 1:3

  result <- joinspy:::.detect_case_mismatch(x, y)

  expect_false(result$has_issues)
})

test_that(".detect_encoding_issues finds invisible characters", {
  # Zero-width space
  x <- c("A\u200BB", "C")

  result <- joinspy:::.detect_encoding_issues(x)

  expect_true(result$has_issues)
  expect_true(length(result$invisible_chars) > 0)
})

test_that(".detect_encoding_issues handles clean strings", {
  x <- c("ABC", "DEF")

  result <- joinspy:::.detect_encoding_issues(x)

  expect_false(result$has_issues)
})

test_that(".summarize_keys counts correctly", {
  df <- data.frame(
    id = c(1, 2, 2, 3, NA),
    val = 1:5
  )

  result <- joinspy:::.summarize_keys(df, "id")

  expect_equal(result$n_rows, 5)
  expect_equal(result$n_unique, 3)  # 1, 2, 3
  expect_equal(result$n_duplicates, 1)  # only 2 is duplicated
  expect_equal(result$n_na, 1)
})

test_that(".summarize_keys handles multi-column keys", {
  df <- data.frame(
    a = c(1, 1, 1, 2),
    b = c("x", "x", "y", "x"),
    val = 1:4
  )

  result <- joinspy:::.summarize_keys(df, c("a", "b"))

  expect_equal(result$n_rows, 4)
  expect_equal(result$n_unique, 3)  # (1,x), (1,y), (2,x)
  expect_equal(result$n_duplicates, 1)  # (1,x) appears twice
})

test_that(".analyze_match computes overlap correctly", {
  x_keys <- c(1, 2, 3)
  y_keys <- c(2, 3, 4)

  result <- joinspy:::.analyze_match(x_keys, y_keys, 3)

  expect_equal(result$n_matched, 2)
  expect_equal(result$n_left_only, 1)
  expect_equal(result$n_right_only, 1)
})

test_that(".predict_row_counts handles 1:1 correctly", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- joinspy:::.predict_row_counts(x, y, "id")

  expect_equal(result$inner, 2)
  expect_equal(result$left, 3)
  expect_equal(result$right, 3)
  expect_equal(result$full, 4)
})

test_that(".predict_row_counts handles duplicates correctly", {
  x <- data.frame(id = c(1, 2, 2), val = 1:3)
  y <- data.frame(id = c(1, 2), name = c("A", "B"))

  result <- joinspy:::.predict_row_counts(x, y, "id")

  # Inner: 1*1 + 2*1 = 3
 expect_equal(result$inner, 3)
})
