# =============================================================================
# Phase 5: Visualization Functions
# =============================================================================

#' Plot Venn Diagram of Key Overlap
#'
#' Creates a simple Venn diagram showing the overlap between keys in two tables.
#'
#' @param report A `JoinReport` object from [join_spy()].
#' @param file Optional file path to save the plot (PNG or SVG based on extension).
#'   If NULL, displays in the current graphics device.
#' @param width Width in inches (default 6).
#' @param height Height in inches (default 5).
#' @param colors Character vector of length 2 for left and right circle colors.
#'
#' @return Invisibly returns the plot data.
#'
#' @examples
#' orders <- data.frame(id = 1:5, val = 1:5)
#' customers <- data.frame(id = 3:7, name = letters[3:7])
#'
#' report <- join_spy(orders, customers, by = "id")
#' plot_venn(report)
#'
#' @seealso [join_spy()], [plot_summary()]
#' @export
plot_venn <- function(report, file = NULL, width = 6, height = 5,
                      colors = c("#4A90D9", "#D94A4A")) {
  if (!is_join_report(report)) {
    stop("`report` must be a JoinReport object", call. = FALSE)
  }

  # Get counts
  left_only <- report$match_analysis$n_left_only
  right_only <- report$match_analysis$n_right_only
  both <- report$match_analysis$n_matched
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
  by_str <- paste(report$by, collapse = ", ")
  graphics::title(main = paste("Key Overlap:", by_str), cex.main = 1.2)

  # Add percentages as subtitle
  pct_match <- round(report$match_analysis$match_rate * 100, 1)
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

#' Plot Join Summary Table
#'
#' Creates a formatted summary table suitable for reports or presentations.
#'
#' @param report A `JoinReport` object from [join_spy()].
#' @param format Output format: "text" (default), "markdown", or "data.frame".
#'
#' @return Formatted table (printed for text/markdown, returned for data.frame).
#'
#' @examples
#' orders <- data.frame(id = 1:5, val = 1:5)
#' customers <- data.frame(id = 3:7, name = letters[3:7])
#'
#' report <- join_spy(orders, customers, by = "id")
#' plot_summary(report, format = "markdown")
#'
#' @seealso [join_spy()], [plot_venn()]
#' @export
plot_summary <- function(report, format = c("text", "markdown", "data.frame")) {
  if (!is_join_report(report)) {
    stop("`report` must be a JoinReport object", call. = FALSE)
  }

  format <- match.arg(format)

  # Build summary data frame
  summary_df <- data.frame(
    Metric = c(
      "Left table rows",
      "Right table rows",
      "Unique left keys",
      "Unique right keys",
      "Keys in both",
      "Keys only in left",
      "Keys only in right",
      "Match rate",
      "Issues detected",
      "Expected inner_join",
      "Expected left_join",
      "Expected right_join",
      "Expected full_join"
    ),
    Value = c(
      report$x_summary$n_rows,
      report$y_summary$n_rows,
      report$x_summary$n_unique,
      report$y_summary$n_unique,
      report$match_analysis$n_matched,
      report$match_analysis$n_left_only,
      report$match_analysis$n_right_only,
      paste0(round(report$match_analysis$match_rate * 100, 1), "%"),
      length(report$issues),
      report$expected_rows$inner,
      report$expected_rows$left,
      report$expected_rows$right,
      report$expected_rows$full
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
      cat(sprintf("| %s | %s |\n", summary_df$Metric[i], summary_df$Value[i]))
    }
  } else {
    # Text format
    max_metric_len <- max(nchar(summary_df$Metric))
    for (i in seq_len(nrow(summary_df))) {
      cat(sprintf(
        "%s: %s\n",
        format(summary_df$Metric[i], width = max_metric_len),
        summary_df$Value[i]
      ))
    }
  }

  invisible(summary_df)
}
