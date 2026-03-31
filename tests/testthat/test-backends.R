# =============================================================================
# Tests for backend dispatch system
# =============================================================================

test_that(".detect_backend returns 'base' for plain data.frames", {
  x <- data.frame(id = 1:3)
  y <- data.frame(id = 1:3)
  expect_equal(.detect_backend(x, y), "base")
})

test_that(".detect_backend returns 'dplyr' for tibbles", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3)
  y <- data.frame(id = 1:3)
  expect_equal(.detect_backend(x, y), "dplyr")
  expect_equal(.detect_backend(y, x), "dplyr")
})

test_that(".detect_backend returns 'data.table' for data.tables", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3)
  y <- data.frame(id = 1:3)
  expect_equal(.detect_backend(x, y), "data.table")
  expect_equal(.detect_backend(y, x), "data.table")
})

test_that(".detect_backend prefers data.table over dplyr when both present", {
  skip_if_not_installed("data.table")
  skip_if_not_installed("dplyr")
  x <- data.table::data.table(id = 1:3)
  y <- tibble::tibble(id = 1:3)
  expect_equal(.detect_backend(x, y), "data.table")
})

# -- Base backend joins -------------------------------------------------------

test_that("base backend performs correct left join", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = "id", type = "left", backend = "base")
  expect_equal(nrow(result), 3)
  expect_true(is.na(result$score[result$id == 1]))
})

test_that("base backend performs correct inner join", {
  x <- data.frame(id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = "id", type = "inner", backend = "base")
  expect_equal(nrow(result), 2)
  expect_equal(sort(result$id), c(2, 3))
})

test_that("base backend handles named by vector", {
  x <- data.frame(x_id = 1:3, val = c("a", "b", "c"))
  y <- data.frame(y_id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = c("x_id" = "y_id"), type = "left", backend = "base")
  expect_equal(nrow(result), 3)
})

# -- dplyr backend joins ------------------------------------------------------

test_that("dplyr backend performs correct left join", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = "id", type = "left", backend = "dplyr")
  expect_equal(nrow(result), 3)
  expect_s3_class(result, "tbl_df")
})

test_that("dplyr backend handles named by vector", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(x_id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(y_id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = c("x_id" = "y_id"), type = "inner", backend = "dplyr")
  expect_equal(nrow(result), 2)
})

test_that("dplyr backend auto-detected for tibble input", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = "id", type = "left")
  expect_s3_class(result, "tbl_df")
})

# -- data.table backend joins -------------------------------------------------

test_that("data.table backend performs correct left join", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = "id", type = "left", backend = "data.table")
  expect_equal(nrow(result), 3)
  expect_s3_class(result, "data.table")
})

test_that("data.table backend handles named by vector", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(x_id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(y_id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = c("x_id" = "y_id"), type = "left", backend = "data.table")
  expect_equal(nrow(result), 3)
})

test_that("data.table backend auto-detected for data.table input", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- .perform_join(x, y, by = "id", type = "left")
  expect_s3_class(result, "data.table")
})

# -- Wrapper integration ------------------------------------------------------

test_that("left_join_spy respects explicit backend", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- left_join_spy(x, y, by = "id", .quiet = TRUE, backend = "dplyr")
  expect_s3_class(result, "tbl_df")
})

test_that("join_strict respects explicit backend", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = 1:3, score = c(10, 20, 30))

  result <- join_strict(x, y, by = "id", expect = "1:1", backend = "dplyr")
  expect_s3_class(result, "tbl_df")
})

test_that("invalid backend errors", {
  x <- data.frame(id = 1)
  y <- data.frame(id = 1)
  expect_error(.perform_join(x, y, "id", "left", backend = "polars"),
               "Unknown backend")
})

# -- All join types work across backends --------------------------------------

test_that("all four join types work with dplyr backend", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))

  for (type in c("left", "right", "inner", "full")) {
    result <- .perform_join(x, y, by = "id", type = type, backend = "dplyr")
    expect_true(is.data.frame(result), info = paste("Failed for type:", type))
  }
})

test_that("all four join types work with data.table backend", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(id = c(2, 3, 4), score = c(10, 20, 30))

  for (type in c("left", "right", "inner", "full")) {
    result <- .perform_join(x, y, by = "id", type = type, backend = "data.table")
    expect_true(is.data.frame(result), info = paste("Failed for type:", type))
  }
})
