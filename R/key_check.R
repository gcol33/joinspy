# =============================================================================
# Quick Key Quality Assessment
# =============================================================================

#' Quick Key Quality Check
#'
#' A fast check of join key quality that returns a simple pass/fail status
#' with a brief summary. Use this for quick validation; use [join_spy()] for
#' detailed diagnostics.
#'
#' @param x A data frame (left table in the join).
#' @param y A data frame (right table in the join).
#' @param by A character vector of column names to join by.
#' @param warn Logical. If `TRUE` (default), prints warnings for detected issues.
#'   Set to `FALSE` for silent operation.
#'
#' @return Invisibly returns a logical: `TRUE` if no issues detected, `FALSE` otherwise.
#'   Also prints a brief status message unless `warn = FALSE`.
#'
#' @examples
#' orders <- data.frame(id = c(1, 2, 2, 3), value = 1:4)
#' customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))
#'
#' # Quick check
#' key_check(orders, customers, by = "id")
#'
#' # Silent check
#' is_ok <- key_check(orders, customers, by = "id", warn = FALSE)
#'
#' @seealso [join_spy()], [key_duplicates()]
#' @export
key_check <- function(x, y, by, warn = TRUE) {
  # Validate inputs
  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Handle named by vector (e.g., c("id" = "customer_id"))
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  # Check columns exist
  missing_x <- setdiff(x_by, names(x))
  missing_y <- setdiff(y_by, names(y))
  if (length(missing_x) > 0) {
    stop("Column(s) not found in x: ", paste(missing_x, collapse = ", "), call. = FALSE)
  }
  if (length(missing_y) > 0) {
    stop("Column(s) not found in y: ", paste(missing_y, collapse = ", "), call. = FALSE)
  }

  issues <- character(0)

  # Get key summaries
  x_summary <- .summarize_keys(x, x_by)
  y_summary <- .summarize_keys(y, y_by)

  # Check for duplicates

  if (x_summary$n_duplicates > 0) {
    issues <- c(issues, sprintf(
      "Left table has %d duplicate key(s) (%d rows affected)",
      x_summary$n_duplicates, x_summary$n_duplicate_rows
    ))
  }
  if (y_summary$n_duplicates > 0) {
    issues <- c(issues, sprintf(
      "Right table has %d duplicate key(s) (%d rows affected)",
      y_summary$n_duplicates, y_summary$n_duplicate_rows
    ))
  }

  # Check for NAs
  if (x_summary$n_na > 0) {
    issues <- c(issues, sprintf("Left table has %d NA key(s)", x_summary$n_na))
  }
  if (y_summary$n_na > 0) {
    issues <- c(issues, sprintf("Right table has %d NA key(s)", y_summary$n_na))
  }

  # Check string issues (only for character columns)
  for (i in seq_along(x_by)) {
    if (is.character(x[[x_by[i]]])) {
      ws <- .detect_whitespace(x[[x_by[i]]])
      if (ws$has_issues) {
        issues <- c(issues, sprintf(
          "Left table column '%s' has whitespace issues (%d values)",
          x_by[i], length(ws$affected_values)
        ))
      }
    }
    if (is.character(y[[y_by[i]]])) {
      ws <- .detect_whitespace(y[[y_by[i]]])
      if (ws$has_issues) {
        issues <- c(issues, sprintf(
          "Right table column '%s' has whitespace issues (%d values)",
          y_by[i], length(ws$affected_values)
        ))
      }
    }

    # Case mismatch check
    if (is.character(x[[x_by[i]]]) && is.character(y[[y_by[i]]])) {
      cm <- .detect_case_mismatch(x[[x_by[i]]], y[[y_by[i]]])
      if (cm$has_issues) {
        issues <- c(issues, sprintf(
          "Column '%s'/'%s' has %d case mismatch(es)",
          x_by[i], y_by[i], nrow(cm$mismatches)
        ))
      }
    }
  }

  is_ok <- length(issues) == 0

  if (warn) {
    if (is_ok) {
      cli_alert_success("Key check passed: no issues detected")
    } else {
      cli_alert_warning("Key check found {length(issues)} issue(s):")
      for (issue in issues) {
        cli_alert_danger(issue)
      }
    }
  }

  invisible(is_ok)
}


#' Find Duplicate Keys
#'
#' Identifies rows with duplicate values in the specified key columns.
#' Returns a data frame containing only the rows with duplicated keys,
#' along with a count of occurrences.
#'
#' @param data A data frame.
#' @param by A character vector of column names to check for duplicates.
#' @param keep Character. Which duplicates to return:
#' \describe{
#'   \item{"all"}{Return all rows with duplicated keys (default)}
#'   \item{"first"}{Return only the first occurrence of each duplicate}
#'   \item{"last"}{Return only the last occurrence of each duplicate}
#' }
#'
#' @return A data frame containing the duplicated rows, with an additional
#'   column `.n_duplicates` showing how many times each key appears.
#'   Returns an empty data frame (0 rows) if no duplicates found.
#'
#' @examples
#' df <- data.frame(
#'   id = c(1, 2, 2, 3, 3, 3, 4),
#'   value = letters[1:7]
#' )
#'
#' # Find all duplicates
#' key_duplicates(df, by = "id")
#'
#' # Find first occurrence only
#' key_duplicates(df, by = "id", keep = "first")
#'
#' @seealso [key_check()], [join_spy()]
#' @export
key_duplicates <- function(data, by, keep = c("all", "first", "last")) {
  keep <- match.arg(keep)

  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)

  # Check columns exist
  missing <- setdiff(by, names(data))
  if (length(missing) > 0) {
    stop("Column(s) not found: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  # Create composite key if multiple columns
  if (length(by) == 1) {
    keys <- data[[by]]
  } else {
    keys <- do.call(paste, c(data[by], sep = "\x1F"))
  }

  # Find duplicated keys (count occurrences)
  key_counts <- table(keys)
  dup_keys <- names(key_counts[key_counts > 1])

  if (length(dup_keys) == 0) {
    # Return empty data frame with same structure plus .n_duplicates
    result <- data[0, , drop = FALSE]
    result$.n_duplicates <- integer(0)
    return(result)
  }

  # Find rows with duplicate keys
  is_dup <- keys %in% dup_keys
  dup_data <- data[is_dup, , drop = FALSE]
  dup_keys_vec <- keys[is_dup]

  # Add count column
  dup_data$.n_duplicates <- as.integer(key_counts[dup_keys_vec])

  # Handle keep argument
  if (keep == "all") {
    return(dup_data)
  }

  # For first/last, keep only one row per key
  if (keep == "first") {
    keep_idx <- !duplicated(dup_keys_vec)
  } else {
    keep_idx <- !duplicated(dup_keys_vec, fromLast = TRUE)
  }

  dup_data[keep_idx, , drop = FALSE]
}
