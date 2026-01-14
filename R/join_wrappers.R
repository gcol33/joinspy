# =============================================================================
# Join Wrappers with Diagnostics
# =============================================================================

# Package environment for storing last report (deferred access) and logging config
.joinspy_env <- new.env(parent = emptyenv())
.joinspy_env$last_report <- NULL
.joinspy_env$log_file <- NULL
.joinspy_env$log_format <- "text"

#' Get the Last Join Report
#'
#' Retrieves the most recent `JoinReport` object from any `*_join_spy()` call.
#' Useful when using `.quiet = TRUE` in pipelines and wanting to inspect
#' the diagnostics afterward.
#'
#' @return The last `JoinReport` object, or `NULL` if no join has been performed.
#'
#' @examples
#' orders <- data.frame(id = 1:3, value = c(10, 20, 30))
#' customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))
#'
#' # Silent join in a pipeline
#' result <- left_join_spy(orders, customers, by = "id", .quiet = TRUE)
#'
#' # Inspect the report afterward
#' last_report()
#'
#' @seealso [left_join_spy()], [join_spy()]
#' @export
last_report <- function() {
  .joinspy_env$last_report
}

#' Internal join wrapper helper
#' @param x Left data frame.
#' @param y Right data frame.
#' @param by Column names.
#' @param type Join type.
#' @param verbose Print output.
#' @param .quiet Suppress all output (overrides verbose).
#' @param ... Additional args to merge.
#' @return Joined data frame with report attribute.
#' @keywords internal
.join_spy_impl <- function(x, y, by, type, verbose, .quiet = FALSE, ...) {
  # Get diagnostic report first
  report <- join_spy(x, y, by)

  # Store for deferred access
  .joinspy_env$last_report <- report

  # Auto-log if configured
  log_file <- .joinspy_env$log_file
  if (!is.null(log_file)) {
    log_format <- .joinspy_env$log_format
    if (log_format == "json") {
      json_data <- .report_to_list(report, timestamp = TRUE)
      json_str <- .to_json(json_data)
      cat(json_str, "\n", file = log_file, append = TRUE, sep = "")
    } else {
      text <- .report_to_text(report, timestamp = TRUE)
      cat("\n", text, "\n", file = log_file, append = TRUE, sep = "")
    }
  }

  # Determine if we should print (verbose and not quiet)
  should_print <- verbose && !.quiet

  # Print if verbose
  if (should_print) {
    print(report)
    cat("\n")
    cli_alert_info("Performing {.val {type}} join...")
  }

  # Handle named by vector
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  # Perform the join
  all_x <- type %in% c("left", "full")
  all_y <- type %in% c("right", "full")

  if (is.null(names(by))) {
    result <- merge(x, y, by = by, all.x = all_x, all.y = all_y, ...)
  } else {
    result <- merge(x, y, by.x = x_by, by.y = y_by, all.x = all_x, all.y = all_y, ...)
  }

  if (should_print) {
    expected <- report$expected_rows[[type]]
    actual <- nrow(result)
    if (actual == expected) {
      cli_alert_success("Result: {.val {actual}} rows (as expected)")
    } else {
      cli_alert_warning("Result: {.val {actual}} rows (expected {.val {expected}})")
    }
  }

  # Attach report as attribute
  attr(result, "join_report") <- report

  result
}

#' Left Join with Diagnostics
#'
#' Performs a left join and automatically prints diagnostic information about
#' the operation. The diagnostic report is also attached as an attribute.
#'
#' @param x A data frame (left table).
#' @param y A data frame (right table).
#' @param by A character vector of column names to join by.
#' @param verbose Logical. If `TRUE` (default), prints diagnostic summary.
#' @param .quiet Logical. If `TRUE`, suppresses all output (overrides `verbose`).
#'   Useful for silent pipeline operations. Use [last_report()] to access the
#'   diagnostics afterward.
#' @param ... Additional arguments passed to the underlying join function.
#'
#' @return The joined data frame with a `"join_report"` attribute containing
#'   the diagnostic information.
#'
#' @examples
#' orders <- data.frame(id = 1:3, value = c(10, 20, 30))
#' customers <- data.frame(id = c(1, 2, 4), name = c("A", "B", "D"))
#'
#' result <- left_join_spy(orders, customers, by = "id")
#'
#' # Access the diagnostic report
#' attr(result, "join_report")
#'
#' # Silent mode for pipelines
#' result2 <- left_join_spy(orders, customers, by = "id", .quiet = TRUE)
#' last_report()  # Access diagnostics afterward
#'
#' @seealso [join_spy()], [join_strict()], [last_report()]
#' @export
left_join_spy <- function(x, y, by, verbose = TRUE, .quiet = FALSE, ...) {
  .join_spy_impl(x, y, by, type = "left", verbose = verbose, .quiet = .quiet, ...)
}


#' Right Join with Diagnostics
#'
#' Performs a right join and automatically prints diagnostic information.
#'
#' @inheritParams left_join_spy
#'
#' @return The joined data frame with a `"join_report"` attribute.
#'
#' @seealso [left_join_spy()], [join_spy()], [last_report()]
#' @export
right_join_spy <- function(x, y, by, verbose = TRUE, .quiet = FALSE, ...) {
  .join_spy_impl(x, y, by, type = "right", verbose = verbose, .quiet = .quiet, ...)
}


#' Inner Join with Diagnostics
#'
#' Performs an inner join and automatically prints diagnostic information.
#'
#' @inheritParams left_join_spy
#'
#' @return The joined data frame with a `"join_report"` attribute.
#'
#' @seealso [left_join_spy()], [join_spy()], [last_report()]
#' @export
inner_join_spy <- function(x, y, by, verbose = TRUE, .quiet = FALSE, ...) {
  .join_spy_impl(x, y, by, type = "inner", verbose = verbose, .quiet = .quiet, ...)
}


#' Full Join with Diagnostics
#'
#' Performs a full join and automatically prints diagnostic information.
#'
#' @inheritParams left_join_spy
#'
#' @return The joined data frame with a `"join_report"` attribute.
#'
#' @seealso [left_join_spy()], [join_spy()], [last_report()]
#' @export
full_join_spy <- function(x, y, by, verbose = TRUE, .quiet = FALSE, ...) {
  .join_spy_impl(x, y, by, type = "full", verbose = verbose, .quiet = .quiet, ...)
}
