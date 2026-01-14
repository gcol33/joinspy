# =============================================================================
# JoinReport S3 Class
# =============================================================================

#' Create a JoinReport Object
#'
#' @param x_summary Summary statistics for keys in the left table.
#' @param y_summary Summary statistics for keys in the right table.
#' @param match_analysis Details of which keys will/won't match.
#' @param issues List of detected problems.
#' @param expected_rows Predicted row counts for each join type.
#' @param by The columns used for joining.
#'
#' @return A `JoinReport` S3 object.
#' @keywords internal
new_join_report <- function(x_summary, y_summary, match_analysis, issues,
                            expected_rows, by) {
  structure(
    list(
      x_summary = x_summary,
      y_summary = y_summary,
      match_analysis = match_analysis,
      issues = issues,
      expected_rows = expected_rows,
      by = by
    ),
    class = "JoinReport"
  )
}

#' Print Method for JoinReport
#'
#' @param x A `JoinReport` object.
#' @param ... Additional arguments (ignored).
#'
#' @return Invisibly returns `x`.
#' @export
print.JoinReport <- function(x, ...) {
  cli_h1("Join Diagnostic Report")

  # Sampling notice
  if (!is.null(x$sampling) && x$sampling$sampled) {
    cli_alert_info("Sampled analysis: {.val {x$sampling$sample_size}} rows from {.val {x$sampling$original_x_rows}} (x) and {.val {x$sampling$original_y_rows}} (y)")
  }

  # Key columns
  by_display <- if (is.null(names(x$by))) {
    paste(x$by, collapse = ", ")
  } else {
    paste(
      paste0(names(x$by), " = ", x$by),
      collapse = ", "
    )
  }
  cli_text("Join columns: {.field {by_display}}")
  cat("\n")

  # Table summaries
  cli_h2("Table Summary")
  cli_text("Left table:
\t Rows: {.val {x$x_summary$n_rows}}
\t Unique keys: {.val {x$x_summary$n_unique}}
\t Duplicate keys: {.val {x$x_summary$n_duplicates}}
\t NA keys: {.val {x$x_summary$n_na}}")
  cli_text("Right table:
\t Rows: {.val {x$y_summary$n_rows}}
\t Unique keys: {.val {x$y_summary$n_unique}}
\t Duplicate keys: {.val {x$y_summary$n_duplicates}}
\t NA keys: {.val {x$y_summary$n_na}}")
  cat("\n")

  # Match analysis
  cli_h2("Match Analysis")
  cli_text("Keys in both: {.val {x$match_analysis$n_matched}}")
  cli_text("Keys only in left: {.val {x$match_analysis$n_left_only}}")
  cli_text("Keys only in right: {.val {x$match_analysis$n_right_only}}")
  match_pct <- round(x$match_analysis$match_rate * 100, 1)
  cli_text("Match rate (left): {.val {match_pct}%}")
  cat("\n")

  # Issues
  if (length(x$issues) > 0) {
    cli_h2("Issues Detected")
    for (issue in x$issues) {
      severity <- issue$severity %||% "warning"
      msg <- issue$message
      if (severity == "error") {
        cli_alert_danger(msg)
      } else if (severity == "warning") {
        cli_alert_warning(msg)
      } else {
        cli_alert_info(msg)
      }
    }
    cat("\n")
  }

  # Multi-column breakdown (Phase 2)
  if (!is.null(x$multicolumn_analysis) && x$multicolumn_analysis$is_multicolumn) {
    cli_h2("Per-Column Breakdown")
    for (col_name in names(x$multicolumn_analysis$column_analysis)) {
      ca <- x$multicolumn_analysis$column_analysis[[col_name]]
      rate_pct <- round(ca$match_rate * 100, 1)
      cli_text("{.field {col_name}}: {.val {rate_pct}%} match rate ({.val {ca$matched}}/{.val {ca$x_unique}})")
    }
    if (!is.null(x$multicolumn_analysis$problem_column)) {
      cli_alert_info("Lowest match rate: {.field {x$multicolumn_analysis$problem_column}}")
    }
    cat("\n")
  }

  # Expected rows
  cli_h2("Expected Row Counts")
  cli_text("inner_join: {.val {x$expected_rows$inner}}")
  cli_text("left_join:
\t {.val {x$expected_rows$left}}")
  cli_text("right_join: {.val {x$expected_rows$right}}")
  cli_text("full_join:
\t {.val {x$expected_rows$full}}")

  invisible(x)
}

#' Check if Object is a JoinReport
#'
#' @param x An object to test.
#' @return `TRUE` if `x` is a `JoinReport`, `FALSE` otherwise.
#' @export
is_join_report <- function(x) {
  inherits(x, "JoinReport")
}

#' Summary Method for JoinReport
#'
#' Returns a compact summary data frame of the join diagnostic report.
#'
#' @param object A `JoinReport` object.
#' @param ... Additional arguments (ignored).
#'
#' @return A data frame with key metrics.
#'
#' @examples
#' orders <- data.frame(id = 1:5, val = 1:5)
#' customers <- data.frame(id = 3:7, name = letters[3:7])
#'
#' report <- join_spy(orders, customers, by = "id")
#' summary(report)
#'
#' @export
summary.JoinReport <- function(object, ...) {
  data.frame(
    metric = c(
      "left_rows", "right_rows",
      "left_unique_keys", "right_unique_keys",
      "keys_matched", "keys_left_only", "keys_right_only",
      "match_rate",
      "issues",
      "inner_join_rows", "left_join_rows", "right_join_rows", "full_join_rows"
    ),
    value = c(
      object$x_summary$n_rows,
      object$y_summary$n_rows,
      object$x_summary$n_unique,
      object$y_summary$n_unique,
      object$match_analysis$n_matched,
      object$match_analysis$n_left_only,
      object$match_analysis$n_right_only,
      round(object$match_analysis$match_rate, 4),
      length(object$issues),
      object$expected_rows$inner,
      object$expected_rows$left,
      object$expected_rows$right,
      object$expected_rows$full
    ),
    stringsAsFactors = FALSE
  )
}

#' Plot Method for JoinReport
#'
#' Creates a Venn diagram showing key overlap between tables.
#'
#' @param x A `JoinReport` object.
#' @param type Type of plot: `"venn"` (default) for Venn diagram.
#' @param ... Additional arguments passed to [plot_venn()].
#'
#' @return Invisibly returns the plot data.
#'
#' @examples
#' orders <- data.frame(id = 1:5, val = 1:5)
#' customers <- data.frame(id = 3:7, name = letters[3:7])
#'
#' report <- join_spy(orders, customers, by = "id")
#' plot(report)
#'
#' @seealso [plot_venn()], [plot_summary()]
#' @export
plot.JoinReport <- function(x, type = c("venn"), ...) {
  type <- match.arg(type)

  if (type == "venn") {
    plot_venn(x, ...)
  }
}
