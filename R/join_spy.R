# =============================================================================
# Main Diagnostic Function
# =============================================================================

#' Comprehensive Pre-Join Diagnostic Report
#'
#' Analyzes two data frames before joining to detect potential issues and
#' predict the outcome. Returns a detailed report of key quality, match rates,
#' and detected problems.
#'
#' @param x A data frame (left table in the join).
#' @param y A data frame (right table in the join).
#' @param by A character vector of column names to join by, or a named character
#'   vector for joins where column names differ (e.g., `c("id" = "customer_id")`).
#' @param sample Integer or NULL. If provided, randomly sample this many rows
#'   from each table for faster diagnostics on large datasets. Default NULL
#'   (analyze all rows).
#' @param ... Reserved for future use.
#'
#' @return A `JoinReport` object with the following components:
#' \describe{
#'   \item{x_summary}{Summary statistics for keys in the left table}
#'   \item{y_summary}{Summary statistics for keys in the right table}
#'   \item{match_analysis}{Details of which keys will/won't match}
#'   \item{issues}{List of detected problems (duplicates, whitespace, etc.)}
#'   \item{expected_rows}{Predicted row counts for each join type}
#' }
#'
#' @details
#' This function detects the following common join issues:
#' \itemize{
#'   \item \strong{Duplicate keys}: Keys appearing multiple times, which cause
#'     row multiplication during joins
#'   \item \strong{Whitespace}: Leading or trailing spaces that prevent matches
#'   \item \strong{Case mismatches}: Keys that differ only by case (e.g., "ABC" vs "abc")
#'   \item \strong{Encoding issues}: Different character encodings or invisible
#'     Unicode characters
#'   \item \strong{NA values}: Missing values in key columns
#' }
#'
#' @examples
#' # Create sample data with issues
#' orders <- data.frame(
#'   order_id = 1:5,
#'   customer_id = c("A", "B", "B", "C", "D ")
#' )
#' customers <- data.frame(
#'   customer_id = c("A", "B", "C", "E"),
#'   name = c("Alice", "Bob", "Carol", "Eve")
#' )
#'
#' # Get diagnostic report
#' join_spy(orders, customers, by = "customer_id")
#'
#' @seealso [key_check()], [join_explain()], [join_strict()]
#' @export
join_spy <- function(x, y, by, sample = NULL, ...) {
  # Validate inputs
  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Store original sizes for reporting
  original_x_rows <- nrow(x)
  original_y_rows <- nrow(y)
  sampled <- FALSE

  # Phase 4: Sampling mode for large datasets
  if (!is.null(sample) && is.numeric(sample) && sample > 0) {
    sample <- as.integer(sample)
    if (nrow(x) > sample) {
      x <- x[base::sample(nrow(x), sample), , drop = FALSE]
      sampled <- TRUE
    }
    if (nrow(y) > sample) {
      y <- y[base::sample(nrow(y), sample), , drop = FALSE]
      sampled <- TRUE
    }
  }

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

  # Get key summaries
  x_summary <- .summarize_keys(x, x_by)
  y_summary <- .summarize_keys(y, y_by)

  # Get keys for analysis
  if (length(x_by) == 1) {
    x_keys <- x[[x_by]]
    y_keys <- y[[y_by]]
  } else {
    x_keys <- do.call(paste, c(x[x_by], sep = "\x1F"))
    y_keys <- do.call(paste, c(y[y_by], sep = "\x1F"))
  }

  # Match analysis
  match_analysis <- .analyze_match(x_keys, y_keys, nrow(x))

  # Collect issues
  issues <- list()

  # Check for duplicates
  if (x_summary$n_duplicates > 0) {
    issues <- c(issues, list(list(
      type = "duplicates",
      table = "x",
      severity = "warning",
      message = sprintf(
        "Left table has %d duplicate key(s) affecting %d rows - may cause row multiplication",
        x_summary$n_duplicates, x_summary$n_duplicate_rows
      ),
      details = x_summary$duplicate_keys
    )))
  }
  if (y_summary$n_duplicates > 0) {
    issues <- c(issues, list(list(
      type = "duplicates",
      table = "y",
      severity = "warning",
      message = sprintf(
        "Right table has %d duplicate key(s) affecting %d rows - may cause row multiplication",
        y_summary$n_duplicates, y_summary$n_duplicate_rows
      ),
      details = y_summary$duplicate_keys
    )))
  }

  # Check for NAs
  if (x_summary$n_na > 0) {
    issues <- c(issues, list(list(
      type = "na",
      table = "x",
      severity = "warning",
      message = sprintf("Left table has %d NA key(s) - these will not match", x_summary$n_na)
    )))
  }
  if (y_summary$n_na > 0) {
    issues <- c(issues, list(list(
      type = "na",
      table = "y",
      severity = "warning",
      message = sprintf("Right table has %d NA key(s) - these will not match", y_summary$n_na)
    )))
  }

  # Check string issues for each key column
  for (i in seq_along(x_by)) {
    # Whitespace in x
    if (is.character(x[[x_by[i]]])) {
      ws <- .detect_whitespace(x[[x_by[i]]])
      if (ws$has_issues) {
        issues <- c(issues, list(list(
          type = "whitespace",
          table = "x",
          column = x_by[i],
          severity = "warning",
          message = sprintf(
            "Left column '%s' has %d value(s) with leading/trailing whitespace",
            x_by[i], length(ws$affected_values)
          ),
          details = ws$affected_values
        )))
      }

      enc <- .detect_encoding_issues(x[[x_by[i]]])
      if (enc$has_issues) {
        issues <- c(issues, list(list(
          type = "encoding",
          table = "x",
          column = x_by[i],
          severity = "warning",
          message = sprintf(
            "Left column '%s' has encoding issues (invisible chars or mixed encoding)",
            x_by[i]
          ),
          details = enc$affected_values
        )))
      }
    }

    # Whitespace in y
    if (is.character(y[[y_by[i]]])) {
      ws <- .detect_whitespace(y[[y_by[i]]])
      if (ws$has_issues) {
        issues <- c(issues, list(list(
          type = "whitespace",
          table = "y",
          column = y_by[i],
          severity = "warning",
          message = sprintf(
            "Right column '%s' has %d value(s) with leading/trailing whitespace",
            y_by[i], length(ws$affected_values)
          ),
          details = ws$affected_values
        )))
      }

      enc <- .detect_encoding_issues(y[[y_by[i]]])
      if (enc$has_issues) {
        issues <- c(issues, list(list(
          type = "encoding",
          table = "y",
          column = y_by[i],
          severity = "warning",
          message = sprintf(
            "Right column '%s' has encoding issues (invisible chars or mixed encoding)",
            y_by[i]
          ),
          details = enc$affected_values
        )))
      }
    }

    # Case mismatches between x and y
    if (is.character(x[[x_by[i]]]) && is.character(y[[y_by[i]]])) {
      cm <- .detect_case_mismatch(x[[x_by[i]]], y[[y_by[i]]])
      if (cm$has_issues) {
        issues <- c(issues, list(list(
          type = "case_mismatch",
          column_x = x_by[i],
          column_y = y_by[i],
          severity = "warning",
          message = sprintf(
            "%d key(s) would match if case-insensitive (e.g., '%s' vs '%s')",
            nrow(cm$mismatches),
            cm$mismatches$x_key[1],
            cm$mismatches$y_key[1]
          ),
          details = cm$mismatches
        )))
      }
    }

    # Phase 2: Type mismatch detection
    type_check <- .detect_type_mismatch(
      x[[x_by[i]]], y[[y_by[i]]],
      x_by[i], y_by[i]
    )
    if (type_check$has_issues) {
      issues <- c(issues, type_check$issues)
    }

    # Phase 2: Factor level mismatch detection
    factor_check <- .detect_factor_mismatch(
      x[[x_by[i]]], y[[y_by[i]]],
      x_by[i], y_by[i]
    )
    if (factor_check$has_issues) {
      issues <- c(issues, factor_check$issues)
    }

    # Phase 2: Empty string detection
    if (is.character(x[[x_by[i]]])) {
      empty_x <- .detect_empty_strings(x[[x_by[i]]])
      if (empty_x$has_issues) {
        issues <- c(issues, list(list(
          type = "empty_string",
          table = "x",
          column = x_by[i],
          severity = "info",
          message = sprintf(
            "Left column '%s' has %d empty string(s) - these match other empty strings but not NA",
            x_by[i], empty_x$n_empty
          )
        )))
      }
    }
    if (is.character(y[[y_by[i]]])) {
      empty_y <- .detect_empty_strings(y[[y_by[i]]])
      if (empty_y$has_issues) {
        issues <- c(issues, list(list(
          type = "empty_string",
          table = "y",
          column = y_by[i],
          severity = "info",
          message = sprintf(
            "Right column '%s' has %d empty string(s) - these match other empty strings but not NA",
            y_by[i], empty_y$n_empty
          )
        )))
      }
    }

    # Phase 2: Numeric precision detection
    if (is.numeric(x[[x_by[i]]])) {
      prec_x <- .detect_numeric_precision(x[[x_by[i]]])
      if (prec_x$has_issues) {
        for (issue in prec_x$issues) {
          issue$table <- "x"
          issue$column <- x_by[i]
          issues <- c(issues, list(issue))
        }
      }
    }
    if (is.numeric(y[[y_by[i]]])) {
      prec_y <- .detect_numeric_precision(y[[y_by[i]]])
      if (prec_y$has_issues) {
        for (issue in prec_y$issues) {
          issue$table <- "y"
          issue$column <- y_by[i]
          issues <- c(issues, list(issue))
        }
      }
    }

    # Phase 2: Near-match detection (only for character columns with unmatched keys)
    if (is.character(x[[x_by[i]]]) && is.character(y[[y_by[i]]])) {
      near <- .detect_near_matches(
        unique(x[[x_by[i]]]),
        unique(y[[y_by[i]]])
      )
      if (near$has_issues) {
        examples <- head(near$near_matches, 3)
        example_str <- paste(
          sprintf("'%s' ~ '%s'", examples$x_key, examples$y_key),
          collapse = ", "
        )
        issues <- c(issues, list(list(
          type = "near_match",
          column_x = x_by[i],
          column_y = y_by[i],
          severity = "info",
          message = sprintf(
            "%d near-match(es) found (e.g., %s) - possible typos?",
            nrow(near$near_matches), example_str
          ),
          details = near$near_matches
        )))
      }
    }
  }

  # Phase 2: Multi-column key analysis
  multicolumn <- .analyze_multicolumn_keys(x, y, x_by, y_by)

  # Predict row counts
  expected_rows <- .predict_row_counts(x, y, by)

  # Create and return JoinReport
  report <- new_join_report(
    x_summary = x_summary,
    y_summary = y_summary,
    match_analysis = match_analysis,
    issues = issues,
    expected_rows = expected_rows,
    by = by
  )

  # Add multicolumn analysis to report
  report$multicolumn_analysis <- multicolumn

  # Add sampling info
  if (sampled) {
    report$sampling <- list(
      sampled = TRUE,
      original_x_rows = original_x_rows,
      original_y_rows = original_y_rows,
      sample_size = sample
    )
  }

  # Phase 4: Memory estimation
  avg_row_bytes <- mean(c(
    as.numeric(object.size(x)) / max(nrow(x), 1),
    as.numeric(object.size(y)) / max(nrow(y), 1)
  ))
  report$memory_estimate <- list(
    inner = .format_bytes(expected_rows$inner * avg_row_bytes * 1.5),
    left = .format_bytes(expected_rows$left * avg_row_bytes * 1.5),
    right = .format_bytes(expected_rows$right * avg_row_bytes * 1.5),
    full = .format_bytes(expected_rows$full * avg_row_bytes * 1.5)
  )

  report
}

#' Format Bytes as Human-Readable String
#' @param bytes Numeric bytes.
#' @return Character string.
#' @keywords internal
.format_bytes <- function(bytes) {
  if (is.na(bytes) || bytes < 1024) {
    return(paste0(round(bytes), " B"))
  } else if (bytes < 1024^2) {
    return(paste0(round(bytes / 1024, 1), " KB"))
  } else if (bytes < 1024^3) {
    return(paste0(round(bytes / 1024^2, 1), " MB"))
  } else {
    return(paste0(round(bytes / 1024^3, 1), " GB"))
  }
}
