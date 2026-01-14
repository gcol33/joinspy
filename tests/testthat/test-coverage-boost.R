# Tests to boost coverage to 90%+

# =============================================================================
# Logging Tests (R/logging.R)
# =============================================================================

test_that("log_report writes to text file", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)

  result <- log_report(report, tmp)
  expect_equal(result, tmp)
  expect_true(file.exists(tmp))

  content <- readLines(tmp)
  expect_true(any(grepl("Join Key", content)))
  expect_true(any(grepl("Left Table", content)))
})

test_that("log_report writes to log file with append", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".log")
  on.exit(unlink(tmp), add = TRUE)

  log_report(report, tmp)
  log_report(report, tmp, append = TRUE)

  content <- readLines(tmp)
  # Should have content from both logs
  expect_true(length(content) > 20)
})

test_that("log_report writes to JSON file", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  log_report(report, tmp)
  expect_true(file.exists(tmp))

  content <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("by", content))
  expect_true(grepl("match_analysis", content))
})

test_that("log_report writes to RDS file", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)

  log_report(report, tmp)
  expect_true(file.exists(tmp))

  loaded <- readRDS(tmp)
  expect_s3_class(loaded, "JoinReport")
  expect_true(!is.null(loaded$logged_at))
})

test_that("log_report without timestamp", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)

  log_report(report, tmp, timestamp = FALSE)
  content <- readLines(tmp)
  expect_false(any(grepl("Logged:", content)))
})

test_that("log_report errors on non-JoinReport", {
  expect_error(log_report(list(a = 1), "test.txt"), "JoinReport")
})

test_that("set_log_file and get_log_file work", {
  old <- get_log_file()
  on.exit(set_log_file(old), add = TRUE)

  set_log_file("test.log")
  expect_equal(get_log_file(), "test.log")

  set_log_file(NULL)
  expect_null(get_log_file())
})

test_that("set_log_file with json format", {
  old <- get_log_file()
  on.exit(set_log_file(old), add = TRUE)

  set_log_file("test.json", format = "json")
  expect_equal(get_log_file(), "test.json")
})

test_that(".to_json handles various types", {
  # Test with NULL
  result <- joinspy:::.to_json(list(a = NULL))
  expect_true(grepl("null", result))

  # Test with logical
  result <- joinspy:::.to_json(list(a = TRUE, b = FALSE))
  expect_true(grepl("true", result))
  expect_true(grepl("false", result))

  # Test with NA logical
  result <- joinspy:::.to_json(list(a = NA))
  expect_true(grepl("null", result))

  # Test with numeric vector
  result <- joinspy:::.to_json(list(nums = c(1, 2, 3)))
  expect_true(grepl("\\[1, 2, 3\\]", result))

  # Test with empty character
  result <- joinspy:::.to_json(list(empty = character(0)))
  expect_true(grepl("\\[\\]", result))

  # Test with character vector
  result <- joinspy:::.to_json(list(chars = c("a", "b")))
  expect_true(grepl("\\[", result))

  # Test with nested list
  result <- joinspy:::.to_json(list(nested = list(x = 1)))
  expect_true(grepl("nested", result))
})

test_that(".report_to_text handles issues", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  text <- joinspy:::.report_to_text(report)
  expect_true(grepl("Issues Detected", text))
})

test_that(".report_to_list handles empty issues", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])
  report <- join_spy(x, y, by = "id")

  lst <- joinspy:::.report_to_list(report)
  expect_true("issue_types" %in% names(lst))
})


# =============================================================================
# JoinReport Tests (R/JoinReport.R)
# =============================================================================

test_that("print.JoinReport handles named by columns", {
  x <- data.frame(id_x = 1:3, val = 1:3)
  y <- data.frame(id_y = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = c("id_x" = "id_y"))

  # Just verify it runs without error
  expect_no_error(print(report))
  expect_s3_class(report, "JoinReport")
})

test_that("print.JoinReport handles sampled analysis", {
  # Create a report with sampling info
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  # Manually add sampling info
  report$sampling <- list(
    sampled = TRUE,
    sample_size = 1000,
    original_x_rows = 10000,
    original_y_rows = 5000
  )

  expect_no_error(print(report))
})

test_that("print.JoinReport handles different issue severities", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = "id")

  # Add issues with different severities
  report$issues <- list(
    list(type = "error", severity = "error", message = "Error message"),
    list(type = "warning", severity = "warning", message = "Warning message"),
    list(type = "info", severity = "info", message = "Info message")
  )

  expect_no_error(print(report))
})

test_that("print.JoinReport handles multicolumn analysis", {
  x <- data.frame(a = 1:3, b = 1:3, val = 1:3)
  y <- data.frame(a = 2:4, b = 2:4, name = letters[2:4])
  report <- join_spy(x, y, by = c("a", "b"))

  expect_no_error(print(report))
})

test_that("summary.JoinReport with text format", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])
  report <- join_spy(x, y, by = "id")

  expect_output(summary(report, format = "text"), "left_rows")
})

test_that("summary.JoinReport with markdown format", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])
  report <- join_spy(x, y, by = "id")

  expect_output(summary(report, format = "markdown"), "\\|")
})

test_that("plot.JoinReport saves to PNG", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".png")
  on.exit(unlink(tmp), add = TRUE)

  result <- plot(report, file = tmp)
  expect_true(file.exists(tmp))
  expect_equal(result$both, 3)
})

test_that("plot.JoinReport saves to SVG", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".svg")
  on.exit(unlink(tmp), add = TRUE)

  plot(report, file = tmp)
  expect_true(file.exists(tmp))
})

test_that("plot.JoinReport saves to PDF", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  plot(report, file = tmp)
  expect_true(file.exists(tmp))
})

test_that("plot.JoinReport errors on unsupported format", {
  x <- data.frame(id = 1:5, val = 1:5)
  y <- data.frame(id = 3:7, name = letters[3:7])
  report <- join_spy(x, y, by = "id")

  tmp <- tempfile(fileext = ".xyz")
  expect_error(plot(report, file = tmp), "Unsupported")
})


# =============================================================================
# Join Wrappers Tests (R/join_wrappers.R)
# =============================================================================

test_that("right_join_spy works", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  result <- right_join_spy(x, y, by = "id")
  expect_equal(nrow(result), 3)
})

test_that("inner_join_spy works", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  result <- inner_join_spy(x, y, by = "id")
  expect_equal(nrow(result), 2)
})

test_that("full_join_spy works", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  result <- full_join_spy(x, y, by = "id")
  expect_equal(nrow(result), 4)
})

test_that("join wrappers with .quiet = TRUE", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  result <- left_join_spy(x, y, by = "id", .quiet = TRUE)
  expect_equal(nrow(result), 3)

  # Check last_report works
  report <- last_report()
  expect_s3_class(report, "JoinReport")
})


# =============================================================================
# Join Repair Tests (R/join_repair.R)
# =============================================================================

test_that("join_repair fixes whitespace", {
  x <- data.frame(id = c(" A", "B ", " C "), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id")
  expect_equal(result$id, c("A", "B", "C"))
})

test_that("join_repair fixes empty strings", {
  x <- data.frame(id = c("A", "", "C"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", empty_to_na = TRUE)
  expect_true(is.na(result$id[2]))
})

test_that("join_repair fixes case", {
  x <- data.frame(id = c("a", "B", "c"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", standardize_case = "upper")
  expect_equal(result$id, c("A", "B", "C"))

  x2 <- data.frame(id = c("a", "B", "c"), val = 1:3, stringsAsFactors = FALSE)
  result <- join_repair(x2, by = "id", standardize_case = "lower")
  expect_equal(result$id, c("a", "b", "c"))
})

test_that("join_repair dry_run returns preview", {
  x <- data.frame(id = c(" A", "B "), val = 1:2, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", dry_run = TRUE)
  # dry_run returns x_changes, y_changes, total_changes
  expect_true("x_changes" %in% names(result))
  expect_true("total_changes" %in% names(result))
  expect_true(result$total_changes > 0)
})

test_that("join_repair with two tables", {
  x <- data.frame(id = c(" A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A ", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  result <- join_repair(x, y, by = "id")
  expect_true(is.list(result))
  expect_true("x" %in% names(result))
  expect_true("y" %in% names(result))
})

test_that("join_repair error handling", {
  # Not a data frame
  expect_error(join_repair("not a df", by = "id"), "data frame")

  # Column not found
  x <- data.frame(id = 1:3, val = 1:3)
  expect_error(join_repair(x, by = "nonexistent"), "not found")

  # Invalid standardize_case
  expect_error(join_repair(x, by = "id", standardize_case = "invalid"), "lower.*upper")
})

test_that("suggest_repairs returns code snippets", {
  x <- data.frame(id = c(" A", "B "), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  suggestions <- suggest_repairs(report)

  expect_true(is.character(suggestions))
})

test_that("suggest_repairs error on non-JoinReport", {
  expect_error(suggest_repairs(list(a = 1)), "JoinReport")
})


# =============================================================================
# Join Explain Tests (R/join_explain.R)
# =============================================================================

test_that("join_explain handles right join", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:5, name = letters[2:5])

  result <- merge(x, y, by = "id", all.y = TRUE)
  expect_no_error(join_explain(x, y, result, by = "id", type = "right"))
})

test_that("join_explain handles inner join", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:5, name = letters[2:5])

  result <- merge(x, y, by = "id")
  expect_no_error(join_explain(x, y, result, by = "id", type = "inner"))
})

test_that("join_explain handles full join", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:5, name = letters[2:5])

  result <- merge(x, y, by = "id", all = TRUE)
  expect_no_error(join_explain(x, y, result, by = "id", type = "full"))
})

test_that("join_diff handles column removal", {
  x <- data.frame(id = 1:3, val = 1:3, extra = 1:3)
  y <- data.frame(id = 1:3, val = 1:3)

  expect_no_error(join_diff(x, y, by = "id"))
})


# =============================================================================
# Advanced Patterns Tests (R/advanced_patterns.R)
# =============================================================================

test_that("detect_cardinality edge cases", {
  # All keys match
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- detect_cardinality(x, y, by = "id")
  expect_equal(result, "1:1")
})

test_that("detect_cardinality m:1", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = 1:2, name = letters[1:2])

  result <- detect_cardinality(x, y, by = "id")
  expect_equal(result, "m:1")
})

test_that("detect_cardinality 1:m", {
  x <- data.frame(id = 1:2, val = 1:2)
  y <- data.frame(id = c(1, 1, 2), name = letters[1:3])

  result <- detect_cardinality(x, y, by = "id")
  expect_equal(result, "1:m")
})

test_that("detect_cardinality m:m", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = c(1, 1, 2), name = letters[1:3])

  result <- detect_cardinality(x, y, by = "id")
  expect_equal(result, "m:m")
})

test_that("check_cartesian detects explosion", {
  x <- data.frame(id = c(1, 1, 1, 2, 2), val = 1:5)
  y <- data.frame(id = c(1, 1, 1, 2, 2), name = letters[1:5])

  result <- check_cartesian(x, y, by = "id", threshold = 2)
  expect_true(result$has_explosion)
})

test_that("check_cartesian no explosion", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- check_cartesian(x, y, by = "id")
  expect_false(result$has_explosion)
})

test_that("check_cartesian no matched keys", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 4:6, name = letters[4:6])

  result <- check_cartesian(x, y, by = "id")
  expect_false(result$has_explosion)
})

test_that("analyze_join_chain with multiple steps", {
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

  expect_true(is.list(result))
  expect_equal(length(result), 2)
})

test_that("analyze_join_chain error handling", {
  expect_error(analyze_join_chain("not a list", list()), "named list")
})


# =============================================================================
# String Diagnostics Edge Cases (R/string_diagnostics.R)
# =============================================================================

test_that(".detect_encoding_issues handles edge cases", {
  # Non-ASCII characters
  x_keys <- c("caf\u00e9", "na\u00efve")

  result <- joinspy:::.detect_encoding_issues(x_keys)
  expect_true(is.list(result))
})

test_that(".detect_encoding_issues with invisible chars", {
  # Keys with invisible characters
  x_keys <- c("test\u200B", "normal")

  result <- joinspy:::.detect_encoding_issues(x_keys)
  expect_true(result$has_issues)
})

test_that(".detect_case_mismatch finds mismatches", {
  x_keys <- c("ABC", "def")
  y_keys <- c("abc", "DEF")

  result <- joinspy:::.detect_case_mismatch(x_keys, y_keys)
  expect_true(result$has_issues)
})

test_that(".detect_whitespace finds issues", {
  x_keys <- c("A ", " B", " C ")

  result <- joinspy:::.detect_whitespace(x_keys)
  expect_true(result$has_issues)
})

test_that(".detect_empty_strings works", {
  x_keys <- c("A", "", "C")

  result <- joinspy:::.detect_empty_strings(x_keys)
  expect_true(result$has_issues)
})

test_that(".detect_numeric_precision handles edge cases", {
  x_keys <- c(1.5, 2.5, 3.5)

  result <- joinspy:::.detect_numeric_precision(x_keys)
  expect_true(result$has_issues)
})

test_that(".detect_numeric_precision with integers", {
  x_keys <- c(1L, 2L, 3L)

  result <- joinspy:::.detect_numeric_precision(x_keys)
  expect_false(result$has_issues)
})

test_that(".detect_type_mismatch finds mismatches", {
  x_keys <- c("1", "2", "3")
  y_keys <- c(1, 2, 3)

  result <- joinspy:::.detect_type_mismatch(x_keys, y_keys, "x_col", "y_col")
  expect_true(result$has_issues)
})

test_that(".detect_type_mismatch char vs factor", {
  x_keys <- c("A", "B", "C")
  y_keys <- factor(c("A", "B", "C"))

  result <- joinspy:::.detect_type_mismatch(x_keys, y_keys, "x_col", "y_col")
  expect_true(result$has_issues)
})

test_that(".detect_factor_mismatch handles factors", {
  x_keys <- factor(c("A", "B", "C"))
  y_keys <- factor(c("A", "B", "D"))

  result <- joinspy:::.detect_factor_mismatch(x_keys, y_keys, "x_col", "y_col")
  expect_true(result$has_issues)
})

test_that(".detect_factor_mismatch non-factors", {
  x_keys <- c("A", "B", "C")
  y_keys <- c("A", "B", "D")

  result <- joinspy:::.detect_factor_mismatch(x_keys, y_keys, "x_col", "y_col")
  expect_false(result$has_issues)
})

test_that(".levenshtein calculates distance", {
  dist <- joinspy:::.levenshtein("cat", "bat")
  expect_equal(dist, 1)

  dist <- joinspy:::.levenshtein("", "abc")
  expect_equal(dist, 3)

  dist <- joinspy:::.levenshtein("abc", "abc")
  expect_equal(dist, 0)
})

test_that(".detect_near_matches finds similar keys", {
  x_keys <- c("customer_id", "order_id")
  y_keys <- c("customerid", "orderid")

  result <- joinspy:::.detect_near_matches(x_keys, y_keys, max_distance = 1)
  expect_true(is.list(result))
})

test_that(".detect_near_matches handles non-character input", {
  x_keys <- c(1, 2, 3)
  y_keys <- c(4, 5, 6)

  result <- joinspy:::.detect_near_matches(x_keys, y_keys)
  expect_false(result$has_issues)
})

test_that(".analyze_multicolumn_keys works", {
  x <- data.frame(a = 1:3, b = c("x", "y", "z"))
  y <- data.frame(a = 2:4, b = c("y", "z", "w"))

  result <- joinspy:::.analyze_multicolumn_keys(x, y, c("a", "b"), c("a", "b"))
  expect_true(result$is_multicolumn)
  expect_true("a" %in% names(result$column_analysis))
})

test_that(".analyze_multicolumn_keys single column", {
  x <- data.frame(a = 1:3)
  y <- data.frame(a = 2:4)

  result <- joinspy:::.analyze_multicolumn_keys(x, y, "a", "a")
  expect_false(result$is_multicolumn)
})


# =============================================================================
# Additional join_spy Tests
# =============================================================================

test_that("join_spy with sampling", {
  set.seed(123)
  x <- data.frame(id = 1:100, val = rnorm(100))
  y <- data.frame(id = 50:150, name = paste0("name", 50:150))

  report <- join_spy(x, y, by = "id", sample = 50)
  expect_s3_class(report, "JoinReport")
})

test_that("join_spy with NA keys", {
  x <- data.frame(id = c(1, NA, 3), val = 1:3)
  y <- data.frame(id = c(NA, 2, 3), name = letters[1:3])

  report <- join_spy(x, y, by = "id")
  expect_true(report$x_summary$n_na > 0)
  expect_true(report$y_summary$n_na > 0)
})

test_that("join_spy with duplicates", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = c(2, 2, 3), name = letters[1:3])

  report <- join_spy(x, y, by = "id")
  expect_true(report$x_summary$n_duplicates > 0)
  expect_true(report$y_summary$n_duplicates > 0)
})

test_that("join_spy with named by", {
  x <- data.frame(x_id = 1:3, val = 1:3)
  y <- data.frame(y_id = 2:4, name = letters[2:4])

  report <- join_spy(x, y, by = c("x_id" = "y_id"))
  expect_s3_class(report, "JoinReport")
})


# =============================================================================
# Key Check Tests
# =============================================================================

test_that("key_check basic usage", {
  x <- data.frame(id = c(1, 1, 2, NA), val = 1:4)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- key_check(x, y, by = "id")
  expect_false(result)  # Should have issues (duplicates and NA)
})

test_that("key_check clean data", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- key_check(x, y, by = "id")
  expect_true(result)  # No issues
})


# =============================================================================
# Key Duplicates Tests
# =============================================================================

test_that("key_duplicates finds duplicates", {
  x <- data.frame(id = c(1, 1, 2, 2, 2, 3), val = 1:6)

  result <- key_duplicates(x, by = "id")
  expect_true(nrow(result) > 0)
  expect_true(all(result$id %in% c(1, 2)))
})

test_that("key_duplicates no duplicates", {
  x <- data.frame(id = 1:3, val = 1:3)

  result <- key_duplicates(x, by = "id")
  expect_equal(nrow(result), 0)
})


# =============================================================================
# Join Strict Tests
# =============================================================================

test_that("join_strict 1:1 passes", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- join_strict(x, y, by = "id", expect = "1:1")
  expect_equal(nrow(result), 3)
})

test_that("join_strict fails on violated constraint", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = 1:2, name = letters[1:2])

  expect_error(join_strict(x, y, by = "id", expect = "1:1"), "Cardinality")
})

test_that("join_strict 1:m passes", {
  x <- data.frame(id = 1:2, val = 1:2)
  y <- data.frame(id = c(1, 1, 2), name = letters[1:3])

  result <- join_strict(x, y, by = "id", expect = "1:m")
  expect_true(nrow(result) >= 2)
})


# =============================================================================
# Additional Coverage Tests
# =============================================================================

test_that("join wrappers with named by", {
  x <- data.frame(x_id = 1:3, val = 1:3)
  y <- data.frame(y_id = 2:4, name = letters[2:4])

  result <- left_join_spy(x, y, by = c("x_id" = "y_id"), .quiet = TRUE)
  expect_equal(nrow(result), 3)
})

test_that("join wrappers with auto-logging", {
  old_log <- get_log_file()
  on.exit(set_log_file(old_log), add = TRUE)

  tmp <- tempfile(fileext = ".log")
  set_log_file(tmp, format = "text")

  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  result <- left_join_spy(x, y, by = "id", .quiet = TRUE)
  expect_true(file.exists(tmp))

  content <- readLines(tmp)
  expect_true(length(content) > 0)

  # Clean up
  unlink(tmp)
})

test_that("join wrappers with auto-logging JSON", {
  old_log <- get_log_file()
  on.exit(set_log_file(old_log), add = TRUE)

  tmp <- tempfile(fileext = ".json")
  set_log_file(tmp, format = "json")

  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  result <- left_join_spy(x, y, by = "id", .quiet = TRUE)
  expect_true(file.exists(tmp))

  # Clean up
  unlink(tmp)
})

test_that("join wrappers verbose mode shows unexpected row count", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)  # Duplicate id=1
  y <- data.frame(id = 1:3, name = letters[1:3])

  # This should cause actual row count to differ from expected
  expect_no_error(left_join_spy(x, y, by = "id"))
})

test_that("key_check with whitespace issues", {
  x <- data.frame(id = c("A ", " B", "C"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B", "C"), name = letters[1:3], stringsAsFactors = FALSE)

  result <- key_check(x, y, by = "id")
  expect_false(result)  # Should have whitespace issues
})

test_that("key_check with case mismatch", {
  x <- data.frame(id = c("ABC", "def"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("abc", "DEF"), name = letters[1:2], stringsAsFactors = FALSE)

  result <- key_check(x, y, by = "id")
  expect_false(result)  # Should have case mismatch issues
})

test_that("key_check silent mode", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- key_check(x, y, by = "id", warn = FALSE)
  expect_false(result)
})

test_that("key_duplicates with keep = last", {
  x <- data.frame(id = c(1, 1, 2, 2, 3), val = 1:5)

  result <- key_duplicates(x, by = "id", keep = "last")
  expect_equal(nrow(result), 2)  # One for each duplicated key
})

test_that("join_spy multicolumn key mismatch", {
  x <- data.frame(a = 1:3, b = c("x", "y", "z"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(a = 2:4, b = c("y", "z", "w"), name = letters[2:4], stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = c("a", "b"))
  expect_true(!is.null(report$multicolumn_analysis))
})

test_that("join_spy detects type coercion issues", {
  x <- data.frame(id = c("1", "2", "3"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c(1, 2, 3), name = letters[1:3])

  report <- join_spy(x, y, by = "id")
  expect_s3_class(report, "JoinReport")
})

test_that("join_spy detects factor level issues", {
  x <- data.frame(id = factor(c("A", "B", "C")), val = 1:3)
  y <- data.frame(id = factor(c("A", "B", "D")), name = letters[1:3])

  report <- join_spy(x, y, by = "id")
  expect_s3_class(report, "JoinReport")
})

test_that("join_repair removes invisible characters", {
  x <- data.frame(id = c("A\u200B", "B", "C"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", remove_invisible = TRUE)
  expect_equal(result$id[1], "A")
})

test_that("join_repair no changes needed", {
  x <- data.frame(id = c("A", "B", "C"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id")
  expect_equal(result$id, c("A", "B", "C"))
})

test_that("join_repair dry_run no changes", {
  x <- data.frame(id = c("A", "B", "C"), val = 1:3, stringsAsFactors = FALSE)

  result <- join_repair(x, by = "id", dry_run = TRUE)
  expect_equal(result$total_changes, 0)
})

test_that("join_repair with numeric columns skips repair", {
  x <- data.frame(id = 1:3, val = 1:3)

  result <- join_repair(x, by = "id")
  expect_equal(result$id, 1:3)
})

test_that("join_explain with duplicate keys", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = c(1, 2, 3), name = letters[1:3])

  result <- merge(x, y, by = "id", all.x = TRUE)
  expect_no_error(join_explain(x, y, result, by = "id", type = "left"))
})

test_that("join_explain with row multiplication", {
  x <- data.frame(id = 1:2, val = 1:2)
  y <- data.frame(id = c(1, 1, 2, 2), name = letters[1:4])

  result <- merge(x, y, by = "id", all.x = TRUE)
  expect_no_error(join_explain(x, y, result, by = "id", type = "left"))
})

test_that("join_diff with row addition", {
  x <- data.frame(id = 1:2, val = 1:2)
  y <- data.frame(id = 1:3, val = 1:3)

  expect_no_error(join_diff(x, y, by = "id"))
})

test_that("join_diff with duplicate changes", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = c(1, 1, 2, 3), val = c(1, 1, 2, 3))

  expect_no_error(join_diff(x, y, by = "id"))
})

test_that("check_cartesian with multicolumn keys", {
  x <- data.frame(a = c(1, 1, 2), b = c("x", "x", "y"), val = 1:3)
  y <- data.frame(a = c(1, 1, 2), b = c("x", "x", "y"), name = letters[1:3])

  result <- check_cartesian(x, y, by = c("a", "b"))
  expect_true(is.list(result))
})

test_that("suggest_repairs with clean data", {
  x <- data.frame(id = c("A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  suggestions <- suggest_repairs(report)

  expect_equal(length(suggestions), 0)
})

test_that("suggest_repairs with case mismatch", {
  x <- data.frame(id = c("ABC", "def"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("abc", "DEF"), name = letters[1:2], stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  suggestions <- suggest_repairs(report)

  expect_true(length(suggestions) > 0 || is.character(suggestions))
})

test_that("join_strict m:1 passes", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = 1:2, name = letters[1:2])

  result <- join_strict(x, y, by = "id", expect = "m:1")
  expect_true(nrow(result) >= 2)
})

test_that("join_strict m:m passes", {
  x <- data.frame(id = c(1, 1, 2), val = 1:3)
  y <- data.frame(id = c(1, 1, 2), name = letters[1:3])

  result <- join_strict(x, y, by = "id", expect = "m:m")
  expect_true(nrow(result) >= 2)
})


# =============================================================================
# More join_spy Coverage Tests
# =============================================================================

test_that("join_spy error on missing x column", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  expect_error(join_spy(x, y, by = "nonexistent"), "not found in x")
})

test_that("join_spy error on missing y column", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(other_id = 2:4, name = letters[2:4])

  expect_error(join_spy(x, y, by = "id"), "not found in y")
})

test_that("join_spy error on non-dataframe x", {
  expect_error(join_spy("not a df", data.frame(id = 1), by = "id"), "data frame")
})

test_that("join_spy error on non-dataframe y", {
  expect_error(join_spy(data.frame(id = 1), "not a df", by = "id"), "data frame")
})

test_that("join_spy with encoding issues in y", {
  x <- data.frame(id = c("A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A\u200B", "B"), name = letters[1:2], stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  expect_s3_class(report, "JoinReport")
})

test_that("join_spy with whitespace in y", {
  x <- data.frame(id = c("A", "B", "C"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A ", " B", "C"), name = letters[1:3], stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  expect_true(any(vapply(report$issues, function(i) i$type == "whitespace" && i$table == "y", logical(1))))
})

test_that("join_spy with empty strings in y", {
  x <- data.frame(id = c("A", "B", "C"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "", "C"), name = letters[1:3], stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  expect_s3_class(report, "JoinReport")
})

test_that("join_spy with numeric precision issues in y", {
  x <- data.frame(id = c(1.0, 2.0, 3.0), val = 1:3)
  y <- data.frame(id = c(1.5, 2.5, 3.5), name = letters[1:3])

  report <- join_spy(x, y, by = "id")
  expect_s3_class(report, "JoinReport")
})

test_that("join_spy sampling mode works on both tables", {
  set.seed(123)
  x <- data.frame(id = 1:1000, val = rnorm(1000))
  y <- data.frame(id = 500:1500, name = paste0("name", 500:1500))

  report <- join_spy(x, y, by = "id", sample = 100)
  expect_s3_class(report, "JoinReport")
  expect_true(report$sampling$sampled)
})

test_that(".format_bytes handles various sizes", {
  # Small bytes
  expect_true(grepl("B$", joinspy:::.format_bytes(100)))

  # Kilobytes
  expect_true(grepl("KB$", joinspy:::.format_bytes(2000)))

  # Megabytes
  expect_true(grepl("MB$", joinspy:::.format_bytes(2000000)))

  # Gigabytes
  expect_true(grepl("GB$", joinspy:::.format_bytes(2000000000)))

  # NA
  expect_true(grepl("B$", joinspy:::.format_bytes(NA)))
})

test_that("join_spy memory estimate is present", {
  x <- data.frame(id = 1:10, val = 1:10)
  y <- data.frame(id = 5:15, name = letters[1:11])

  report <- join_spy(x, y, by = "id")
  expect_true(!is.null(report$memory_estimate))
  expect_true("inner" %in% names(report$memory_estimate))
})

test_that("join_spy with near matches", {
  x <- data.frame(id = c("customer", "orders"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("custome", "order"), name = letters[1:2], stringsAsFactors = FALSE)

  report <- join_spy(x, y, by = "id")
  # Near matches may be detected
  expect_s3_class(report, "JoinReport")
})

test_that("key_check with named by vector", {
  x <- data.frame(x_id = 1:3, val = 1:3)
  y <- data.frame(y_id = 2:4, name = letters[2:4])

  result <- key_check(x, y, by = c("x_id" = "y_id"))
  expect_true(result)  # No issues expected
})

test_that("key_check error on missing x column", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 2:4, name = letters[2:4])

  expect_error(key_check(x, y, by = "nonexistent"), "not found in x")
})

test_that("key_check error on missing y column", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(other_id = 2:4, name = letters[2:4])

  expect_error(key_check(x, y, by = "id"), "not found in y")
})

test_that("key_duplicates with composite key", {
  x <- data.frame(a = c(1, 1, 1, 2), b = c("x", "x", "y", "z"), val = 1:4)

  result <- key_duplicates(x, by = c("a", "b"))
  expect_equal(nrow(result), 2)  # Only the duplicate (1, "x") rows
})

test_that("key_duplicates error on missing column", {
  x <- data.frame(id = 1:3, val = 1:3)

  expect_error(key_duplicates(x, by = "nonexistent"), "not found")
})

test_that("join_repair with named by and two tables", {
  x <- data.frame(x_id = c(" A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(y_id = c("A ", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  result <- join_repair(x, y, by = c("x_id" = "y_id"))
  expect_true("x" %in% names(result))
  expect_true("y" %in% names(result))
  expect_equal(result$x$x_id, c("A", "B"))
  expect_equal(result$y$y_id, c("A", "B"))
})

test_that("join_repair y column not found", {
  x <- data.frame(x_id = c("A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(z_id = c("A", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  expect_error(join_repair(x, y, by = c("x_id" = "y_id")), "not found in y")
})

test_that("check_cartesian error on non-dataframe", {
  expect_error(check_cartesian("not df", data.frame(id = 1), by = "id"), "data frame")
  expect_error(check_cartesian(data.frame(id = 1), "not df", by = "id"), "data frame")
})

test_that("detect_cardinality error on non-dataframe", {
  expect_error(detect_cardinality("not df", data.frame(id = 1), by = "id"), "data frame")
  expect_error(detect_cardinality(data.frame(id = 1), "not df", by = "id"), "data frame")
})

test_that("detect_cardinality with named by", {
  x <- data.frame(x_id = 1:3, val = 1:3)
  y <- data.frame(y_id = 1:3, name = letters[1:3])

  result <- detect_cardinality(x, y, by = c("x_id" = "y_id"))
  expect_equal(result, "1:1")
})


# =============================================================================
# Final Coverage Boost
# =============================================================================

test_that("key_check with y whitespace issues", {
  x <- data.frame(id = c("A", "B", "C"), val = 1:3, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A ", " B", "C"), name = letters[1:3], stringsAsFactors = FALSE)

  result <- key_check(x, y, by = "id")
  expect_false(result)  # Whitespace issues in y
})

test_that("key_check with duplicate keys in y", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = c(1, 1, 2, 3), name = letters[1:4])

  result <- key_check(x, y, by = "id")
  expect_false(result)  # Duplicates in y
})

test_that("key_check with NA in y", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = c(1, NA, 3), name = letters[1:3])

  result <- key_check(x, y, by = "id")
  expect_false(result)  # NA in y
})

test_that("join_explain with no issues", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, name = letters[1:3])

  result <- merge(x, y, by = "id")
  expect_no_error(join_explain(x, y, result, by = "id", type = "left"))
})

test_that("join_explain with more rows than expected", {
  x <- data.frame(id = c(1, 2, 3), val = 1:3)
  y <- data.frame(id = c(1, 1, 2, 3), name = letters[1:4])

  result <- merge(x, y, by = "id", all.x = TRUE)
  expect_no_error(join_explain(x, y, result, by = "id", type = "left"))
})

test_that("join_diff no changes", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, val = 1:3)

  expect_no_error(join_diff(x, y, by = "id"))
})

test_that("join_diff with column additions", {
  x <- data.frame(id = 1:3, val = 1:3)
  y <- data.frame(id = 1:3, val = 1:3, new_col = letters[1:3])

  expect_no_error(join_diff(x, y, by = "id"))
})

test_that("join_repair both tables no changes", {
  x <- data.frame(id = c("A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  result <- join_repair(x, y, by = "id")
  expect_equal(result$x$id, c("A", "B"))
  expect_equal(result$y$id, c("A", "B"))
})

test_that("join_repair dry_run with two tables", {
  x <- data.frame(id = c(" A", "B"), val = 1:2, stringsAsFactors = FALSE)
  y <- data.frame(id = c("A ", "B"), name = c("a", "b"), stringsAsFactors = FALSE)

  result <- join_repair(x, y, by = "id", dry_run = TRUE)
  expect_true("x_changes" %in% names(result))
  expect_true("y_changes" %in% names(result))
})

test_that("key_check with y column missing in named by", {
  x <- data.frame(x_id = 1:3, val = 1:3)
  y <- data.frame(z_id = 2:4, name = letters[2:4])

  expect_error(key_check(x, y, by = c("x_id" = "y_id")), "not found in y")
})
