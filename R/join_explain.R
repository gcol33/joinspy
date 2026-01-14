# =============================================================================
# Post-Join Diagnostics
# =============================================================================

#' Explain Row Count Changes After a Join
#'
#' After performing a join, use this function to understand why the row count
#' changed. It analyzes the original tables and the result to explain the
#' difference.
#'
#' @param result The result of a join operation.
#' @param x The original left data frame.
#' @param y The original right data frame.
#' @param by A character vector of column names used in the join.
#' @param type Character. The type of join that was performed. One of
#'   `"left"`, `"right"`, `"inner"`, `"full"`. If `NULL` (default),
#'   attempts to infer the join type from row counts.
#'
#' @return Invisibly returns a list with explanation details. Prints a
#'   human-readable explanation.
#'
#' @examples
#' orders <- data.frame(id = c(1, 2, 2, 3), value = 1:4)
#' customers <- data.frame(id = c(1, 2, 2, 4), name = c("A", "B1", "B2", "D"))
#'
#' result <- merge(orders, customers, by = "id", all.x = TRUE)
#'
#' # Explain why we got more rows than expected
#' join_explain(result, orders, customers, by = "id", type = "left")
#'
#' @seealso [join_spy()], [join_diff()]
#' @export
join_explain <- function(result, x, y, by, type = NULL) {
  # Validate inputs
  if (!is.data.frame(result)) stop("`result` must be a data frame", call. = FALSE)
  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Handle named by vector
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  # Row counts
  n_result <- nrow(result)
  n_x <- nrow(x)
  n_y <- nrow(y)

  # Get key summaries
  x_summary <- .summarize_keys(x, x_by)
  y_summary <- .summarize_keys(y, y_by)

  # Match analysis
  if (length(x_by) == 1) {
    x_keys <- x[[x_by]]
    y_keys <- y[[y_by]]
  } else {
    x_keys <- do.call(paste, c(x[x_by], sep = "\x1F"))
    y_keys <- do.call(paste, c(y[y_by], sep = "\x1F"))
  }
  match_info <- .analyze_match(x_keys, y_keys, n_x)

  # Build explanation
  cli_h1("Join Explanation")

  cli_h2("Row Counts")
  cli_text("Left table (x): {.val {n_x}} rows")
  cli_text("Right table (y): {.val {n_y}} rows")
  cli_text("Result: {.val {n_result}} rows")

  diff <- n_result - n_x
  if (diff > 0) {
    cli_alert_warning("Result has {.val {diff}} more rows than left table")
  } else if (diff < 0) {
    cli_alert_info("Result has {.val {abs(diff)}} fewer rows than left table
")
  } else {
    cli_alert_success("Result has same row count as left table")
  }
  cat("\n")

  cli_h2("Why the row count changed")

  explanations <- character(0)

  # Check for duplicate-induced multiplication
  if (x_summary$n_duplicates > 0 && y_summary$n_duplicates > 0) {
    explanations <- c(explanations,
      "Both tables have duplicate keys - this causes multiplicative row expansion"
    )
  } else if (y_summary$n_duplicates > 0) {
    explanations <- c(explanations, sprintf(
      "Right table has %d duplicate key(s) - each match creates multiple rows",
      y_summary$n_duplicates
    ))
  } else if (x_summary$n_duplicates > 0) {
    explanations <- c(explanations, sprintf(
      "Left table has %d duplicate key(s) - each match creates multiple rows",
      x_summary$n_duplicates
    ))
  }

  # Check for unmatched keys
  if (match_info$n_left_only > 0 && (is.null(type) || type %in% c("left", "full"))) {
    explanations <- c(explanations, sprintf(
      "%d left key(s) have no match in right table",
      match_info$n_left_only
    ))
  }

  if (match_info$n_right_only > 0 && (is.null(type) || type %in% c("right", "full"))) {
    explanations <- c(explanations, sprintf(
      "%d right key(s) have no match in left table",
      match_info$n_right_only
    ))
  }

  if (type == "inner" && match_info$n_left_only > 0) {
    explanations <- c(explanations, sprintf(
      "Inner join dropped %d unmatched left rows",
      match_info$n_left_only
    ))
  }

  # NAs
  if (x_summary$n_na > 0 || y_summary$n_na > 0) {
    explanations <- c(explanations, "NA keys do not match (by design)")
  }

  if (length(explanations) == 0) {
    cli_text("Join was 1:1 with complete key overlap - no unexpected changes")
  } else {
    for (exp in explanations) {
      cli_alert_info(exp)
    }
  }

  # Return details invisibly
  invisible(list(
    n_x = n_x,
    n_y = n_y,
    n_result = n_result,
    diff = diff,
    x_duplicates = x_summary$n_duplicates,
    y_duplicates = y_summary$n_duplicates,
    matched = match_info$n_matched,
    left_only = match_info$n_left_only,
    right_only = match_info$n_right_only
  ))
}


#' Compare Data Frame Before and After Join
#'
#' Shows a side-by-side comparison of key statistics before and after a join
#' operation.
#'
#' @param before The original data frame (before joining).
#' @param after The result data frame (after joining).
#' @param by Optional. Column names to analyze for key statistics.
#'
#' @return Invisibly returns a comparison summary. Prints a formatted comparison.
#'
#' @examples
#' before <- data.frame(id = 1:3, x = letters[1:3])
#' after <- data.frame(id = c(1, 2, 2, 3), x = c("a", "b", "b", "c"), y = 1:4
#' )
#'
#' join_diff(before, after)
#'
#' @seealso [join_explain()], [join_spy()]
#' @export
join_diff <- function(before, after, by = NULL) {
  if (!is.data.frame(before)) stop("`before` must be a data frame", call. = FALSE)
  if (!is.data.frame(after)) stop("`after` must be a data frame", call. = FALSE)

  cli_h1("Join Diff")

  # Basic stats
  cli_h2("Dimensions")
  cli_text("Before: {.val {nrow(before)}} rows x {.val {ncol(before)}} columns")
  cli_text("After:
\t {.val {nrow(after)}} rows x {.val {ncol(after)}} columns")

  row_diff <- nrow(after) - nrow(before)
  col_diff <- ncol(after) - ncol(before)
  cli_text("Change:
\t {.val {sprintf('%+d', row_diff)}} rows, {.val {sprintf('%+d', col_diff)}} columns")
  cat("\n")

  # Column changes
  cli_h2("Column Changes")
  before_cols <- names(before)
  after_cols <- names(after)

  added <- setdiff(after_cols, before_cols)
  removed <- setdiff(before_cols, after_cols)

  if (length(added) > 0) {
    cli_alert_success("Added: {.field {paste(added, collapse = ', ')}}")
  }
  if (length(removed) > 0) {
    cli_alert_danger("Removed: {.field {paste(removed, collapse = ', ')}}")
  }
  if (length(added) == 0 && length(removed) == 0) {
    cli_text("No column changes")
  }
  cat("\n")

  # Key analysis if by is provided
  if (!is.null(by)) {
    cli_h2("Key Analysis")

    missing_by <- setdiff(by, intersect(before_cols, after_cols))
    if (length(missing_by) > 0) {
      cli_alert_warning("Key column(s) not in both: {.field {paste(missing_by, collapse = ', ')}}")
    } else {
      before_summary <- .summarize_keys(before, by)
      after_summary <- .summarize_keys(after, by)

      cli_text("Unique keys before: {.val {before_summary$n_unique}}")
      cli_text("Unique keys after:
\t {.val {after_summary$n_unique}}")

      dup_diff <- after_summary$n_duplicate_rows - before_summary$n_duplicate_rows
      if (dup_diff != 0) {
        cli_text("Duplicate rows: {.val {sprintf('%+d', dup_diff)}}")
      }
    }
  }

  # Return summary invisibly
  invisible(list(
    before_rows = nrow(before),
    after_rows = nrow(after),
    before_cols = ncol(before),
    after_cols = ncol(after),
    columns_added = added,
    columns_removed = removed
  ))
}
