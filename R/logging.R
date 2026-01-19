# =============================================================================
# Phase 7: Logging & Audit Functions
# =============================================================================

#' Log Join Report to File
#'
#' Writes a `JoinReport` object to a file for audit trails and reproducibility.
#' Supports plain text, JSON, and RDS formats.
#'
#' @param report A `JoinReport` object from [join_spy()] or retrieved via
#'   [last_report()].
#' @param file File path to write to. Extension determines format:
#'   - `.txt` or `.log`: Plain text (human-readable)
#'   - `.json`: JSON format (machine-readable)
#'   - `.rds`: R binary format (preserves all data)
#' @param append Logical. If `TRUE`, appends to existing file (text/log only).
#'   Default `FALSE`.
#' @param timestamp Logical. If `TRUE` (default), includes timestamp in output.
#'
#' @return Invisibly returns the file path.
#'
#' @examples
#' orders <- data.frame(id = 1:3, value = c(10, 20, 30))
#' customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))
#'
#' report <- join_spy(orders, customers, by = "id")
#'
#' # Log to temporary file
#' tmp <- tempfile(fileext = ".log")
#' log_report(report, tmp, append = TRUE)
#' unlink(tmp)
#'
#' @seealso [join_spy()], [last_report()]
#' @export
log_report <- function(report, file, append = FALSE, timestamp = TRUE) {
  if (!is_join_report(report)) {
    stop("`report` must be a JoinReport object", call. = FALSE)
  }

  ext <- tolower(tools::file_ext(file))

  if (ext == "rds") {
    # RDS format - preserves complete object
    if (timestamp) {
      report$logged_at <- Sys.time()
    }
    saveRDS(report, file)
  } else if (ext == "json") {
    # JSON format
    json_data <- .report_to_list(report, timestamp = timestamp)
    json_str <- .to_json(json_data)
    writeLines(json_str, file)
  } else {
    # Plain text format (txt, log, or any other)
    text <- .report_to_text(report, timestamp = timestamp)
    if (append && file.exists(file)) {
      cat("\n", text, "\n", file = file, append = TRUE, sep = "")
    } else {
      writeLines(text, file)
    }
  }

  cli_alert_success("Report logged to {.file {file}}")
  invisible(file)
}

#' Convert JoinReport to list for serialization
#' @param report A JoinReport object.
#' @param timestamp Include timestamp.
#' @return List representation.
#' @keywords internal
.report_to_list <- function(report, timestamp = TRUE) {
  result <- list(
    by = report$by,
    x_summary = list(
      n_rows = report$x_summary$n_rows,
      n_unique = report$x_summary$n_unique,
      n_duplicated = report$x_summary$n_duplicated,
      n_na = report$x_summary$n_na
    ),
    y_summary = list(
      n_rows = report$y_summary$n_rows,
      n_unique = report$y_summary$n_unique,
      n_duplicated = report$y_summary$n_duplicated,
      n_na = report$y_summary$n_na
    ),
    match_analysis = list(
      n_matched = report$match_analysis$n_matched,
      n_left_only = report$match_analysis$n_left_only,
      n_right_only = report$match_analysis$n_right_only,
      match_rate = report$match_analysis$match_rate
    ),
    expected_rows = as.list(report$expected_rows),
    n_issues = length(report$issues),
    issue_types = unique(vapply(report$issues, function(i) i$type, character(1)))
  )

  if (timestamp) {
    result$logged_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  }

  result
}

#' Simple JSON serialization (no dependencies)
#' @param x List to convert.
#' @return JSON string.
#' @keywords internal
.to_json <- function(x) {
  .to_json_value <- function(val) {
    if (is.null(val)) {
      "null"
    } else if (is.logical(val)) {
      if (is.na(val)) "null" else if (val) "true" else "false"
    } else if (is.numeric(val)) {
      if (length(val) == 1) {
        as.character(val)
      } else {
        paste0("[", paste(val, collapse = ", "), "]")
      }
    } else if (is.character(val)) {
      if (length(val) == 0) {
        "[]"
      } else if (length(val) == 1) {
        paste0("\"", gsub("\"", "\\\\\"", val), "\"")
      } else {
        paste0("[", paste0("\"", gsub("\"", "\\\\\"", val), "\"", collapse = ", "), "]")
      }
    } else if (is.list(val)) {
      .to_json(val)
    } else {
      paste0("\"", as.character(val), "\"")
    }
  }

  if (is.null(names(x))) {
    # Array
    items <- vapply(x, .to_json_value, character(1))
    paste0("[", paste(items, collapse = ", "), "]")
  } else {
    # Object
    items <- mapply(function(n, v) {
      paste0("\"", n, "\": ", .to_json_value(v))
    }, names(x), x, USE.NAMES = FALSE)
    paste0("{\n  ", paste(items, collapse = ",\n  "), "\n}")
  }
}

#' Convert JoinReport to text
#' @param report A JoinReport object.
#' @param timestamp Include timestamp.
#' @return Character string.
#' @keywords internal
.report_to_text <- function(report, timestamp = TRUE) {
  lines <- character(0)

  if (timestamp) {
    lines <- c(lines, paste0("Logged: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
    lines <- c(lines, paste0(rep("-", 60), collapse = ""))
  }

  lines <- c(lines, paste0("Join Key: ", paste(report$by, collapse = ", ")))
  lines <- c(lines, "")

  # Left table summary
  lines <- c(lines, "Left Table (x):")

  lines <- c(lines, paste0("  Rows: ", report$x_summary$n_rows))
  lines <- c(lines, paste0("  Unique keys: ", report$x_summary$n_unique))
  lines <- c(lines, paste0("  Duplicated keys: ", report$x_summary$n_duplicated))
  lines <- c(lines, paste0("  NA keys: ", report$x_summary$n_na))
  lines <- c(lines, "")

  # Right table summary
  lines <- c(lines, "Right Table (y):")
  lines <- c(lines, paste0("  Rows: ", report$y_summary$n_rows))
  lines <- c(lines, paste0("  Unique keys: ", report$y_summary$n_unique))
  lines <- c(lines, paste0("  Duplicated keys: ", report$y_summary$n_duplicated))
  lines <- c(lines, paste0("  NA keys: ", report$y_summary$n_na))
  lines <- c(lines, "")

  # Match analysis
  lines <- c(lines, "Match Analysis:")
  lines <- c(lines, paste0("  Keys in both: ", report$match_analysis$n_matched))
  lines <- c(lines, paste0("  Keys only in left: ", report$match_analysis$n_left_only))
  lines <- c(lines, paste0("  Keys only in right: ", report$match_analysis$n_right_only))
  lines <- c(lines, paste0("  Match rate: ", round(report$match_analysis$match_rate * 100, 1), "%"))
  lines <- c(lines, "")

  # Expected rows
  lines <- c(lines, "Expected Rows:")
  lines <- c(lines, paste0("  inner_join: ", report$expected_rows$inner))
  lines <- c(lines, paste0("  left_join: ", report$expected_rows$left))
  lines <- c(lines, paste0("  right_join: ", report$expected_rows$right))
  lines <- c(lines, paste0("  full_join: ", report$expected_rows$full))
  lines <- c(lines, "")

  # Issues
  n_issues <- length(report$issues)
  if (n_issues > 0) {
    lines <- c(lines, paste0("Issues Detected: ", n_issues))
    issue_types <- table(vapply(report$issues, function(i) i$type, character(1)))
    for (t in names(issue_types)) {
      lines <- c(lines, paste0("  ", t, ": ", issue_types[t]))
    }
  } else {
    lines <- c(lines, "Issues Detected: 0")
  }

  lines <- c(lines, paste0(rep("=", 60), collapse = ""))

  paste(lines, collapse = "\n")
}

#' Configure Automatic Logging
#'
#' Sets up automatic logging of all join reports to a specified file.
#' When enabled, every `*_join_spy()` call will append its report to the log.
#'
#' @param file File path for automatic logging. Set to `NULL` to disable.
#' @param format Log format: "text" (default) or "json".
#'
#' @return Invisibly returns the previous log file setting.
#'
#' @examples
#' # Enable automatic logging to temp file
#' tmp <- tempfile(fileext = ".log")
#' old <- set_log_file(tmp)
#'
#' # Disable logging and clean up
#' set_log_file(NULL)
#' unlink(tmp)
#'
#' @seealso [log_report()], [get_log_file()]
#' @export
set_log_file <- function(file, format = c("text", "json")) {
  format <- match.arg(format)
  old <- .joinspy_env$log_file

  .joinspy_env$log_file <- file
  .joinspy_env$log_format <- format

  if (!is.null(file)) {
    cli_alert_info("Automatic logging enabled: {.file {file}}")
  } else if (!is.null(old)) {
    cli_alert_info("Automatic logging disabled")
  }

  invisible(old)
}

#' Get Current Log File
#'
#' Returns the current automatic log file path, if set.
#'
#' @return The log file path, or `NULL` if not set.
#'
#' @seealso [set_log_file()]
#' @export
get_log_file <- function() {
  .joinspy_env$log_file
}
