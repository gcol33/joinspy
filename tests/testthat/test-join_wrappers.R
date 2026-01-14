# =============================================================================
# Tests for join wrapper functions
# =============================================================================

test_that("left_join_spy returns correct result", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- left_join_spy(x, y, by = "id", verbose = FALSE)

  expect_equal(nrow(result), 3)
  expect_true("join_report" %in% names(attributes(result)))
})

test_that("right_join_spy returns correct result", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- right_join_spy(x, y, by = "id", verbose = FALSE)

  expect_equal(nrow(result), 3)
  expect_true("join_report" %in% names(attributes(result)))
})

test_that("inner_join_spy returns correct result", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- inner_join_spy(x, y, by = "id", verbose = FALSE)

  expect_equal(nrow(result), 2)
  expect_true("join_report" %in% names(attributes(result)))
})

test_that("full_join_spy returns correct result", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- full_join_spy(x, y, by = "id", verbose = FALSE)

  expect_equal(nrow(result), 4)
  expect_true("join_report" %in% names(attributes(result)))
})

test_that("join wrappers attach JoinReport as attribute", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- left_join_spy(x, y, by = "id", verbose = FALSE)
  report <- attr(result, "join_report")

  expect_s3_class(report, "JoinReport")
  expect_true(is_join_report(report))
})

test_that("join wrappers handle named by vector", {
  x <- data.frame(order_id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  result <- left_join_spy(x, y, by = c("order_id" = "id"), verbose = FALSE)

  expect_equal(nrow(result), 3)
})

test_that("join wrappers work with duplicate keys", {
  x <- data.frame(id = c(1, 2, 2, 3), val = 1:4)
  y <- data.frame(id = c(1, 2, 3), name = c("A", "B", "C"))

  result <- left_join_spy(x, y, by = "id", verbose = FALSE)

  expect_equal(nrow(result), 4)
})
