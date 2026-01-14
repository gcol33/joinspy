# =============================================================================
# Tests for join_strict()
# =============================================================================

test_that("join_strict succeeds with 1:1 relationship when expected", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- join_strict(x, y, by = "id", expect = "1:1")

  expect_equal(nrow(result), 3)
})

test_that("join_strict fails with 1:m when expecting 1:1", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))

  expect_error(
    join_strict(x, y, by = "id", expect = "1:1"),
    "Cardinality violation"
  )
})

test_that("join_strict fails with m:1 when expecting 1:1", {
  x <- data.frame(id = c(1, 1, 2, 3), val = c("a", "b", "c", "d"))
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  expect_error(
    join_strict(x, y, by = "id", expect = "1:1"),
    "Cardinality violation"
  )
})

test_that("join_strict succeeds with 1:m when y has duplicates", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))

  result <- join_strict(x, y, by = "id", expect = "1:m")

  expect_equal(nrow(result), 4)
})

test_that("join_strict fails with 1:m when x has duplicates", {
  x <- data.frame(id = c(1, 1, 2), val = c("a", "b", "c"))
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  expect_error(
    join_strict(x, y, by = "id", expect = "1:m"),
    "Cardinality violation"
  )
})

test_that("join_strict succeeds with m:1 when x has duplicates", {
  x <- data.frame(id = c(1, 1, 2, 3), val = c("a", "b", "c", "d"))
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- join_strict(x, y, by = "id", expect = "m:1")

  expect_equal(nrow(result), 4)
})

test_that("join_strict fails with m:1 when y has duplicates", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))

  expect_error(
    join_strict(x, y, by = "id", expect = "m:1"),
    "Cardinality violation"
  )
})

test_that("join_strict accepts m:m with any cardinality", {
  x <- data.frame(id = c(1, 1, 2), val = c("a", "b", "c"))
  y <- data.frame(id = c(1, 2, 2), name = c("A", "B1", "B2"))

  result <- join_strict(x, y, by = "id", expect = "m:m")

  expect_true(nrow(result) >= 3)
})

test_that("join_strict respects join type", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 2:4, name = c("B", "C", "D"))

  inner_result <- join_strict(x, y, by = "id", type = "inner", expect = "1:1")
  left_result <- join_strict(x, y, by = "id", type = "left", expect = "1:1")
  right_result <- join_strict(x, y, by = "id", type = "right", expect = "1:1")
  full_result <- join_strict(x, y, by = "id", type = "full", expect = "1:1")

  expect_equal(nrow(inner_result), 2)
  expect_equal(nrow(left_result), 3)
  expect_equal(nrow(right_result), 3)
  expect_equal(nrow(full_result), 4)
})

test_that("join_strict accepts alternative cardinality syntax", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))

  # "1:many" should work same as "1:m"
  result <- join_strict(x, y, by = "id", expect = "1:many")
  expect_equal(nrow(result), 4)

  # "many:many" should work same as "m:m"
  result2 <- join_strict(x, y, by = "id", expect = "many:many")
  expect_equal(nrow(result2), 4)
})

test_that("join_strict handles named by vector", {
  x <- data.frame(order_id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- join_strict(x, y, by = c("order_id" = "id"), expect = "1:1")

  expect_equal(nrow(result), 3)
})
