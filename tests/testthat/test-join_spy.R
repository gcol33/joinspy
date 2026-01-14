# =============================================================================
# Tests for join_spy()
# =============================================================================

test_that("join_spy returns JoinReport object", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  report <- join_spy(x, y, by = "id")

  expect_s3_class(report, "JoinReport")
  expect_true(is_join_report(report))
})

test_that("join_spy detects duplicates in left table", {
  x <- data.frame(id = c(1, 1, 2, 3), val = 1:4)
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  report <- join_spy(x, y, by = "id")

  expect_equal(report$x_summary$n_duplicates, 1)
  expect_equal(report$x_summary$n_duplicate_rows, 2)
  expect_true(any(sapply(report$issues, function(i) i$type == "duplicates" && i$table == "x")))
})

test_that("join_spy detects duplicates in right table", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = c(1, 2, 2, 3), name = c("A", "B1", "B2", "C"))

  report <- join_spy(x, y, by = "id")

  expect_equal(report$y_summary$n_duplicates, 1)
  expect_true(any(sapply(report$issues, function(i) i$type == "duplicates" && i$table == "y")))
})

test_that("join_spy detects NA keys", {
  x <- data.frame(id = c(1, NA, 3), val = 1:3)
  y <- data.frame(id = c(1, 2, NA), name = c("A", "B", "C"))

  report <- join_spy(x, y, by = "id")

  expect_equal(report$x_summary$n_na, 1)
  expect_equal(report$y_summary$n_na, 1)
})

test_that("join_spy detects whitespace issues", {
  x <- data.frame(id = c("A", "B ", " C"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B", "C"), name = c("a", "b", "c"), stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")

  ws_issues <- Filter(function(i) i$type == "whitespace", report$issues)
  expect_true(length(ws_issues) > 0)
})

test_that("join_spy detects case mismatches", {
  x <- data.frame(id = c("ABC", "def"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("abc", "DEF"), name = c("a", "d"), stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")

  case_issues <- Filter(function(i) i$type == "case_mismatch", report$issues)
  expect_true(length(case_issues) > 0)
})

test_that("join_spy correctly calculates match analysis", {
  x <- data.frame(id = c(1, 2, 3), val = 1:3)
  y <- data.frame(id = c(2, 3, 4), name = c("B", "C", "D"))

  report <- join_spy(x, y, by = "id")

  expect_equal(report$match_analysis$n_matched, 2)
  expect_equal(report$match_analysis$n_left_only, 1)
  expect_equal(report$match_analysis$n_right_only, 1)
})

test_that("join_spy predicts row counts correctly for 1:1 join", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  report <- join_spy(x, y, by = "id")

  # Inner: 2 matches (id 2 and 3)
  expect_equal(report$expected_rows$inner, 2)
  # Left: 2 matches + 1 unmatched (id 1)
  expect_equal(report$expected_rows$left, 3)
  # Right: 2 matches + 1 unmatched (id 4)
  expect_equal(report$expected_rows$right, 3)
  # Full: 2 matches + 1 left only + 1 right only
  expect_equal(report$expected_rows$full, 4)
})

test_that("join_spy handles named by vector", {
  x <- data.frame(order_id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  report <- join_spy(x, y, by = c("order_id" = "id"))

  expect_equal(report$match_analysis$n_matched, 2)
})

test_that("join_spy handles multi-column keys", {
  x <- data.frame(a = c(1, 1, 2), b = c("x", "y", "x"), val = 1:3)
  y <- data.frame(a = c(1, 2, 2), b = c("x", "x", "y"), name = c("A", "B", "C"))

  report <- join_spy(x, y, by = c("a", "b"))

  expect_equal(report$match_analysis$n_matched, 2)  # (1,x) and (2,x)
})

test_that("join_spy errors on missing columns", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(key = 1:3, name = c("A", "B", "C"))

  expect_error(join_spy(x, y, by = "id"), "not found")
})

test_that("join_spy works with empty data frames", {
  x <- data.frame(id = integer(0), val = character(0))
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  report <- join_spy(x, y, by = "id")

  expect_equal(report$x_summary$n_rows, 0)
  expect_equal(report$match_analysis$n_matched, 0)
})
