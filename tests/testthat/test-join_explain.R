# =============================================================================
# Tests for join_explain() and join_diff()
# =============================================================================

# --- join_explain() tests ---

test_that("join_explain returns invisibly", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))
  result <- merge(x, y, by = "id", all.x = TRUE)

  output <- join_explain(result, x, y, by = "id", type = "left")

  expect_type(output, "list")
  expect_true("n_x" %in% names(output))
  expect_true("n_result" %in% names(output))
})

test_that("join_explain captures correct row counts", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))
  result <- merge(x, y, by = "id", all.x = TRUE)

  output <- join_explain(result, x, y, by = "id", type = "left")

  expect_equal(output$n_x, 3)
  expect_equal(output$n_y, 3)
  expect_equal(output$n_result, 3)
})

test_that("join_explain identifies duplicate-caused expansion", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))
  result <- merge(x, y, by = "id")

  output <- join_explain(result, x, y, by = "id", type = "inner")

  expect_equal(output$y_duplicates, 1)
  expect_true(output$n_result > output$n_x)
})

test_that("join_explain handles named by vector", {
  x <- data.frame(order_id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))
  result <- merge(x, y, by.x = "order_id", by.y = "id", all.x = TRUE)

  output <- join_explain(result, x, y, by = c("order_id" = "id"), type = "left")

  expect_equal(output$matched, 2)
})


# --- join_diff() tests ---

test_that("join_diff returns invisibly", {
  before <- data.frame(id = 1:3, val = 1:3)
  after <- data.frame(id = 1:4, val = 1:4, name = c("A", "B", "C", "D"))

  output <- join_diff(before, after)

  expect_type(output, "list")
})

test_that("join_diff captures dimension changes", {
  before <- data.frame(id = 1:3, val = 1:3)
  after <- data.frame(id = 1:4, val = 1:4, name = c("A", "B", "C", "D"))

  output <- join_diff(before, after)

  expect_equal(output$before_rows, 3)
  expect_equal(output$after_rows, 4)
  expect_equal(output$before_cols, 2)
  expect_equal(output$after_cols, 3)
})

test_that("join_diff identifies added columns", {
  before <- data.frame(id = 1:3, val = 1:3)
  after <- data.frame(id = 1:3, val = 1:3, name = c("A", "B", "C"))

  output <- join_diff(before, after)

  expect_equal(output$columns_added, "name")
})

test_that("join_diff identifies removed columns", {
  before <- data.frame(id = 1:3, val = 1:3, extra = c("x", "y", "z"))
  after <- data.frame(id = 1:3, val = 1:3)

  output <- join_diff(before, after)

  expect_equal(output$columns_removed, "extra")
})

test_that("join_diff handles key analysis when by provided", {
  before <- data.frame(id = 1:3, val = 1:3)
  after <- data.frame(id = c(1, 2, 2, 3), val = 1:4)

  # Should not error when analyzing keys
  output <- join_diff(before, after, by = "id")

  expect_type(output, "list")
})
