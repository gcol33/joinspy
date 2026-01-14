# =============================================================================
# Tests for key_check() and key_duplicates()
# =============================================================================

# --- key_check() tests ---

test_that("key_check returns TRUE when no issues", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- key_check(x, y, by = "id", warn = FALSE)

  expect_true(result)
})

test_that("key_check returns FALSE with duplicates", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- key_check(x, y, by = "id", warn = FALSE)

  expect_false(result)
})

test_that("key_check returns FALSE with NA keys", {
  x <- data.frame(id = c(1, NA, 3), val = 1:3)
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- key_check(x, y, by = "id", warn = FALSE)

  expect_false(result)
})

test_that("key_check returns FALSE with whitespace", {
  x <- data.frame(id = c("A ", "B", "C"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B", "C"), name = c("a", "b", "c"), stringsAsFactors = FALSE)

  result <- key_check(x, y, by = "id", warn = FALSE)

  expect_false(result)
})

test_that("key_check returns FALSE with case mismatches", {
  x <- data.frame(id = c("ABC", "DEF"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("abc", "def"), name = c("a", "d"), stringsAsFactors = FALSE)

  result <- key_check(x, y, by = "id", warn = FALSE)

  expect_false(result)
})

test_that("key_check handles named by vector", {
  x <- data.frame(order_id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = c("A", "B", "C"))

  result <- key_check(x, y, by = c("order_id" = "id"), warn = FALSE)

  expect_true(result)
})

test_that("key_check errors on missing columns", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(key = 1:3, name = c("A", "B", "C"))

  expect_error(key_check(x, y, by = "id", warn = FALSE), "not found")
})


# --- key_duplicates() tests ---

test_that("key_duplicates returns empty data frame when no duplicates", {
  df <- data.frame(id = 1:5, val = letters[1:5])

  result <- key_duplicates(df, by = "id")

  expect_equal(nrow(result), 0)
  expect_true(".n_duplicates" %in% names(result))
})

test_that("key_duplicates finds all duplicate rows", {
  df <- data.frame(
    id = c(1, 2, 2, 3, 3, 3, 4),
    val = letters[1:7]
  )

  result <- key_duplicates(df, by = "id")

  expect_equal(nrow(result), 5)  # 2 rows for id=2, 3 rows for id=3
  expect_true(all(result$id %in% c(2, 3)))
})

test_that("key_duplicates keep='first' returns first occurrence", {
  df <- data.frame(
    id = c(1, 2, 2, 3),
    val = c("a", "b1", "b2", "c")
  )

  result <- key_duplicates(df, by = "id", keep = "first")

  expect_equal(nrow(result), 1)
  expect_equal(result$val, "b1")
})

test_that("key_duplicates keep='last' returns last occurrence", {
  df <- data.frame(
    id = c(1, 2, 2, 3),
    val = c("a", "b1", "b2", "c")
  )

  result <- key_duplicates(df, by = "id", keep = "last")

  expect_equal(nrow(result), 1)
  expect_equal(result$val, "b2")
})

test_that("key_duplicates adds .n_duplicates column", {
  df <- data.frame(
    id = c(1, 2, 2, 3, 3, 3),
    val = 1:6
  )

  result <- key_duplicates(df, by = "id")

  expect_true(".n_duplicates" %in% names(result))
  expect_equal(result$.n_duplicates[result$id == 2][1], 2)
  expect_equal(result$.n_duplicates[result$id == 3][1], 3)
})

test_that("key_duplicates handles multi-column keys", {
  df <- data.frame(
    a = c(1, 1, 1, 2),
    b = c("x", "x", "y", "x"),
    val = 1:4
  )

  result <- key_duplicates(df, by = c("a", "b"))

  expect_equal(nrow(result), 2)  # Only (1, "x") is duplicated
})

test_that("key_duplicates errors on missing columns", {
  df <- data.frame(id = 1:3, val = 1:3)

  expect_error(key_duplicates(df, by = "missing"), "not found")
})
