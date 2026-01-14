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
#' @param format Output format: "data.frame" (default), "text", or "markdown".
#'
#' @return A data frame with key metrics (or printed output for text/markdown).
#'
#' @examples
#' orders <- data.frame(id = 1:5, val = 1:5)
#' customers <- data.frame(id = 3:7, name = letters[3:7])
#'
#' report <- join_spy(orders, customers, by = "id")
#' summary(report)
#' summary(report, format = "markdown")
#'
#' @export
summary.JoinReport <- function(object, format = c("data.frame", "text", "markdown"), ...) {
  format <- match.arg(format)

  summary_df <- data.frame(
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

  if (format == "data.frame") {
    return(summary_df)
  }

  if (format == "markdown") {
    cat("| Metric | Value |\n")
    cat("|--------|-------|\n")
    for (i in seq_len(nrow(summary_df))) {
      cat(sprintf("| %s | %s |\n", summary_df$metric[i], summary_df$value[i]))
    }
  } else {
    # Text format
    max_metric_len <- max(nchar(summary_df$metric))
    for (i in seq_len(nrow(summary_df))) {
      cat(sprintf(
        "%s: %s\n",
        format(summary_df$metric[i], width = max_metric_len),
        summary_df$value[i]
      ))
    }
  }

  invisible(summary_df)
}

#' Plot Method for JoinReport
#'
#' Creates a Venn diagram showing key overlap between tables.
#'
#' @param x A `JoinReport` object.
#' @param file Optional file path to save the plot (PNG, SVG, or PDF based on extension).
#'   If NULL (default), displays in the current graphics device.
#' @param width Width in inches (default 6).
#' @param height Height in inches (default 5).
#' @param colors Character vector of length 2 for left and right circle colors.
#' @param ... Additional arguments (ignored).
#'
#' @return Invisibly returns the plot data (left_only, both, right_only counts).
#'
#' @examples
#' orders <- data.frame(id = 1:5, val = 1:5)
#' customers <- data.frame(id = 3:7, name = letters[3:7])
#'
#' report <- join_spy(orders, customers, by = "id")
#' plot(report)
#'
#' @export
plot.JoinReport <- function(x, file = NULL, width = 6, height = 5,
                            colors = c("#4A90D9", "#D94A4A"), ...) {
  # Get counts

  left_only <- x$match_analysis$n_left_only
  right_only <- x$match_analysis$n_right_only
  both <- x$match_analysis$n_matched

  total <- left_only + both + right_only

  # Open file device if needed
  if (!is.null(file)) {
    ext <- tolower(tools::file_ext(file))
    if (ext == "png") {
      grDevices::png(file, width = width, height = height, units = "in", res = 150)
    } else if (ext == "svg") {
      grDevices::svg(file, width = width, height = height)
    } else if (ext == "pdf") {
      grDevices::pdf(file, width = width, height = height)
    } else {
      stop("Unsupported file format. Use .png, .svg, or .pdf", call. = FALSE)
    }
    on.exit(grDevices::dev.off(), add = TRUE)
  }

  # Set up plot

  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(oldpar), add = TRUE)
  graphics::par(mar = c(1, 1, 3, 1))

  # Create empty plot
  graphics::plot.new()
  graphics::plot.window(xlim = c(-2, 2), ylim = c(-1.5, 1.5))

  # Draw circles with transparency
  col_left <- grDevices::adjustcolor(colors[1], alpha.f = 0.5)
  col_right <- grDevices::adjustcolor(colors[2], alpha.f = 0.5)

  # Left circle (centered at -0.5)
  theta <- seq(0, 2 * pi, length.out = 100)
  x_left <- -0.5 + cos(theta)
  y_left <- sin(theta)
  graphics::polygon(x_left, y_left, col = col_left, border = colors[1], lwd = 2)

  # Right circle (centered at 0.5)
  x_right <- 0.5 + cos(theta)
  y_right <- sin(theta)
  graphics::polygon(x_right, y_right, col = col_right, border = colors[2], lwd = 2)

  # Add labels
  graphics::text(-1, 0, left_only, cex = 1.5, font = 2)
  graphics::text(0, 0, both, cex = 1.5, font = 2)
  graphics::text(1, 0, right_only, cex = 1.5, font = 2)

  # Add legend labels
  graphics::text(-1.5, -1.3, "Left only", cex = 0.9, col = colors[1])
  graphics::text(0, -1.3, "Both", cex = 0.9)
  graphics::text(1.5, -1.3, "Right only", cex = 0.9, col = colors[2])

  # Add title
  by_str <- paste(x$by, collapse = ", ")
  graphics::title(main = paste("Key Overlap:", by_str), cex.main = 1.2)

  # Add percentages as subtitle
  pct_match <- round(x$match_analysis$match_rate * 100, 1)
  graphics::mtext(
    paste0("Match rate: ", pct_match, "% | Total unique keys: ", total),
    side = 3, line = 0.2, cex = 0.8
  )

  invisible(list(
    left_only = left_only,
    both = both,
    right_only = right_only
  ))
}
