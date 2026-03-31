test_that("join_explain works with tibble inputs", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))
  result <- dplyr::left_join(x, y, by = "id")

  out <- join_explain(result, x, y, by = "id", type = "left")
  expect_type(out, "list")
  expect_equal(out$n_result, 3)
})

test_that("join_explain works with data.table inputs", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(id = c(2, 3, 4), score = c(10, 20, 30))
  result <- merge(x, y, by = "id", all.x = TRUE)

  out <- join_explain(result, x, y, by = "id", type = "left")
  expect_type(out, "list")
  expect_equal(out$n_result, 3)
})

test_that("join_diff works with tibble inputs", {
  skip_if_not_installed("dplyr")
  before <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  after <- tibble::tibble(id = 1:3, val = c("a", "b", "c"), extra = 1:3)

  out <- join_diff(before, after, by = "id")
  expect_equal(out$columns_added, "extra")
})

test_that("join_repair preserves tibble class", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = c(" A", "B ", "C"), val = 1:3)
  repaired <- join_repair(x, by = "id")
  expect_s3_class(repaired, "tbl_df")
  expect_equal(repaired$id, c("A", "B", "C"))
})

test_that("join_repair preserves data.table class", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = c(" A", "B ", "C"), val = 1:3)
  repaired <- join_repair(x, by = "id")
  expect_s3_class(repaired, "data.table")
  expect_equal(repaired$id, c("A", "B", "C"))
})

test_that("join_spy works with tibble inputs", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))
  report <- join_spy(x, y, by = "id")
  expect_true(is_join_report(report))
})

test_that("join_spy works with data.table inputs", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(id = c(2, 3, 4), score = c(10, 20, 30))
  report <- join_spy(x, y, by = "id")
  expect_true(is_join_report(report))
})

test_that("full pipeline: tibble in, tibble out", {
  skip_if_not_installed("dplyr")
  x <- tibble::tibble(id = 1:3, val = c("a", "b", "c"))
  y <- tibble::tibble(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- left_join_spy(x, y, by = "id", .quiet = TRUE)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  expect_true(!is.null(attr(result, "join_report")))
})

test_that("full pipeline: data.table in, data.table out", {
  skip_if_not_installed("data.table")
  x <- data.table::data.table(id = 1:3, val = c("a", "b", "c"))
  y <- data.table::data.table(id = c(2, 3, 4), score = c(10, 20, 30))

  result <- left_join_spy(x, y, by = "id", .quiet = TRUE)
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 3)
})
