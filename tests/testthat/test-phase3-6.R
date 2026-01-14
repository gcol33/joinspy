# =============================================================================
# Tests for Phase 3-6 Features
# =============================================================================

# --- Phase 3: join_repair() ---

test_that("join_repair trims whitespace", {
  x <- data.frame(id = c(" A", "B ", " C "), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", trim_whitespace = TRUE)

  expect_equal(result$id, c("A", "B", "C"))
})

test_that("join_repair standardizes case", {
  x <- data.frame(id = c("ABC", "Def", "ghi"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", standardize_case = "lower")

  expect_equal(result$id, c("abc", "def", "ghi"))
})

test_that("join_repair converts empty to NA", {
  x <- data.frame(id = c("A", "", "C"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", empty_to_na = TRUE)

  expect_true(is.na(result$id[2]))
})

test_that("join_repair dry_run mode works", {
  x <- data.frame(id = c(" A", "B "), val = 1:2, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", dry_run = TRUE)

  expect_true(result$total_changes > 0)
  # Original data unchanged in dry run
})

test_that("join_repair handles both x and y", {
  x <- data.frame(id = c(" A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B "), name = c("a", "b"), stringsAsFactors = FALSE)

  result <- join_repair(x, y, by = "id")

  expect_equal(result$x$id, c("A", "B"))
  expect_equal(result$y$id, c("A", "B"))
})


# --- Phase 4: Sampling ---

test_that("join_spy sample parameter works", {
  x <- data.frame(id = 1:1000, val = rnorm(1000))
  y <- data.frame(id = 1:1000, name = sample(letters, 1000, replace = TRUE))

  report <- join_spy(x, y, by = "id", sample = 100)

  expect_true(!is.null(report$sampling))
  expect_true(report$sampling$sampled)
  expect_equal(report$sampling$sample_size, 100)
})

test_that("join_spy includes memory estimates", {
  x <- data.frame(id = 1:100, val = 1:100)
  y <- data.frame(id = 1:100, name = letters[1:100 %% 26 + 1])

  report <- join_spy(x, y, by = "id")

  expect_true(!is.null(report$memory_estimate))
  expect_true(is.character(report$memory_estimate$inner))
})


# --- Phase 5: Visualization ---

test_that("plot_venn runs without error", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])

  report <- join_spy(x, y, by = "id")

  # Should not error
  result <- plot_venn(report)

  expect_equal(result$left_only, 2)
  expect_equal(result$both, 3)
  expect_equal(result$right_only, 2)
})

test_that("plot_summary returns data frame", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])

  report <- join_spy(x, y, by = "id")

  result <- plot_summary(report, format = "data.frame")

  expect_s3_class(result, "data.frame")
  expect_true("Metric" %in% names(result))
  expect_true("Value" %in% names(result))
})


# --- Phase 6: Advanced Patterns ---

test_that("check_cartesian detects explosion risk", {
  x <- data.frame(id = c(1, 1, 1, 2, 2), val_x = 1:5)
  y <- data.frame(id = c(1, 1, 1, 2, 2), val_y = 1:5)

  result <- check_cartesian(x, y, by = "id", threshold = 2)

  expect_true(result$has_explosion)
  expect_true(result$expansion_factor > 2)
})

test_that("check_cartesian passes for safe joins", {
  x <- data.frame(id = 1:5, val_x = 1:5)
  y <- data.frame(id = 1:5, val_y = 1:5)

  result <- check_cartesian(x, y, by = "id")

  expect_false(result$has_explosion)
})

test_that("detect_cardinality correctly identifies relationships", {
  # 1:1
  x1 <- data.frame(id = 1:3, val = 1:3)
  y1 <- data.frame(id = 1:3, name = c("A", "B", "C"))
  expect_equal(detect_cardinality(x1, y1, "id"), "1:1")

  # 1:m
  x2 <- data.frame(id = 1:3, val = 1:3)
  y2 <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))
  expect_equal(detect_cardinality(x2, y2, "id"), "1:m")

  # m:1
  x3 <- data.frame(id = c(1, 1, 2, 3), val = 1:4)
  y3 <- data.frame(id = 1:3, name = c("A", "B", "C"))
  expect_equal(detect_cardinality(x3, y3, "id"), "m:1")

  # m:m
  x4 <- data.frame(id = c(1, 1, 2), val = 1:3)
  y4 <- data.frame(id = c(1, 2, 2), name = c("A", "B1", "B2"))
  expect_equal(detect_cardinality(x4, y4, "id"), "m:m")
})

test_that("analyze_join_chain works with multiple tables", {
  orders <- data.frame(order_id = 1:3, customer_id = c(1, 2, 2))
  customers <- data.frame(customer_id = 1:3, region_id = c(1, 1, 2))
  regions <- data.frame(region_id = 1:2, name = c("North", "South"))

  result <- analyze_join_chain(
    tables = list(orders = orders, customers = customers, regions = regions),
    joins = list(
      list(left = "orders", right = "customers", by = "customer_id"),
      list(left = "result", right = "regions", by = "region_id")
    )
  )

  expect_equal(length(result), 2)
  expect_true(is_join_report(result[[1]]$report))
})
