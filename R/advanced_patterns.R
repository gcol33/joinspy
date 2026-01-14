# =============================================================================
# Phase 6: Advanced Join Pattern Detection
# =============================================================================

#' Detect Potential Cartesian Product
#'
#' Warns if a join will produce a very large result due to many-to-many
#' relationships (Cartesian product explosion).
#'
#' @param x A data frame (left table).
#' @param y A data frame (right table).
#' @param by Column names to join by.
#' @param threshold Warn if result will exceed this many times the larger input.
#'   Default 10.
#'
#' @return A list with explosion analysis.
#'
#' @examples
#' # Dangerous: both tables have duplicates
#' x <- data.frame(id = c(1, 1, 2, 2), val_x = 1:4)
#' y <- data.frame(id = c(1, 1, 2, 2), val_y = 1:4)
#'
#' check_cartesian(x, y, by = "id")
#'
#' @seealso [join_spy()], [join_strict()]
#' @export
check_cartesian <- function(x, y, by, threshold = 10) {
  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Handle named by vector
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  # Get key vectors
  if (length(x_by) == 1) {
    x_keys <- x[[x_by]]
    y_keys <- y[[y_by]]
  } else {
    x_keys <- do.call(paste, c(x[x_by], sep = "\x1F"))
    y_keys <- do.call(paste, c(y[y_by], sep = "\x1F"))
  }

  # Count occurrences per key
  x_counts <- table(x_keys[!is.na(x_keys)])
  y_counts <- table(y_keys[!is.na(y_keys)])

  # Find matched keys
  matched_keys <- intersect(names(x_counts), names(y_counts))

  if (length(matched_keys) == 0) {
    cli_alert_success("No matched keys - no Cartesian product risk")
    return(invisible(list(
      has_explosion = FALSE,
      expansion_factor = 0,
      worst_keys = character(0)
    )))
  }

  # Calculate per-key expansion
  expansions <- vapply(matched_keys, function(k) {
    as.numeric(x_counts[k]) * as.numeric(y_counts[k])
  }, numeric(1))

  # Total expected rows from inner join
  total_inner <- sum(expansions)
  max_input <- max(nrow(x), nrow(y))
  expansion_factor <- total_inner / max_input

  # Find worst offenders
  worst_idx <- order(expansions, decreasing = TRUE)[1:min(5, length(expansions))]
  worst_keys <- data.frame(
    key = matched_keys[worst_idx],
    x_count = as.integer(x_counts[matched_keys[worst_idx]]),
    y_count = as.integer(y_counts[matched_keys[worst_idx]]),
    product = as.integer(expansions[worst_idx]),
    stringsAsFactors = FALSE
  )

  has_explosion <- expansion_factor > threshold

  if (has_explosion) {
    cli_alert_danger("Cartesian product risk: result will be {.val {round(expansion_factor, 1)}}x larger than input")
    cli_h2("Worst offending keys")
    for (i in seq_len(nrow(worst_keys))) {
      cli_text("{.val {worst_keys$key[i]}}: {.val {worst_keys$x_count[i]}} x {.val {worst_keys$y_count[i]}} = {.val {worst_keys$product[i]}} rows")
    }
  } else {
    cli_alert_success("No Cartesian product risk (expansion factor: {.val {round(expansion_factor, 1)}}x)")
  }

  invisible(list(
    has_explosion = has_explosion,
    expansion_factor = expansion_factor,
    total_inner = total_inner,
    worst_keys = worst_keys
  ))
}

#' Analyze Multi-Table Join Chain
#'
#' Analyzes a sequence of joins to identify potential issues in the chain.
#' Useful for debugging complex multi-table joins.
#'
#' @param tables A named list of data frames to join.
#' @param joins A list of join specifications, each with elements:
#'   \describe{
#'     \item{left}{Name of left table}
#'     \item{right}{Name of right table}
#'     \item{by}{Join column(s)}
#'   }
#'
#' @return A summary of the join chain analysis.
#'
#' @examples
#' orders <- data.frame(order_id = 1:3, customer_id = c(1, 2, 2))
#' customers <- data.frame(customer_id = 1:3, region_id = c(1, 1, 2))
#' regions <- data.frame(region_id = 1:2, name = c("North", "South"))
#'
#' analyze_join_chain(
#'   tables = list(orders = orders, customers = customers, regions = regions),
#'   joins = list(
#'     list(left = "orders", right = "customers", by = "customer_id"),
#'     list(left = "result", right = "regions", by = "region_id")
#'   )
#' )
#'
#' @seealso [join_spy()], [check_cartesian()]
#' @export
analyze_join_chain <- function(tables, joins) {
  if (!is.list(tables) || is.null(names(tables))) {
    stop("`tables` must be a named list of data frames", call. = FALSE)
  }

  cli_h1("Join Chain Analysis")

  results <- list()
  current_result <- NULL

  for (i in seq_along(joins)) {
    join_spec <- joins[[i]]
    left_name <- join_spec$left
    right_name <- join_spec$right
    join_by <- join_spec$by

    cli_h2("Step {i}: {left_name} + {right_name}")

    # Get tables
    if (left_name == "result" && !is.null(current_result)) {
      left_df <- current_result
    } else if (left_name %in% names(tables)) {
      left_df <- tables[[left_name]]
    } else {
      cli_alert_danger("Table '{left_name}' not found")
      next
    }

    if (right_name %in% names(tables)) {
      right_df <- tables[[right_name]]
    } else {
      cli_alert_danger("Table '{right_name}' not found")
      next
    }

    # Analyze this join
    report <- join_spy(left_df, right_df, by = join_by)

    cli_text("Left: {.val {nrow(left_df)}} rows")
    cli_text("Right: {.val {nrow(right_df)}} rows")
    cli_text("Match rate: {.val {round(report$match_analysis$match_rate * 100, 1)}}%")
    cli_text("Expected result: {.val {report$expected_rows$left}} rows (left join)")

    if (length(report$issues) > 0) {
      cli_alert_warning("{.val {length(report$issues)}} issue(s) detected")
    }

    results[[i]] <- list(
      step = i,
      left = left_name,
      right = right_name,
      by = join_by,
      report = report
    )

    # Simulate the join result for next step
    current_result <- merge(left_df, right_df,
                            by = if (is.null(names(join_by))) join_by else NULL,
                            by.x = if (!is.null(names(join_by))) names(join_by) else NULL,
                            by.y = if (!is.null(names(join_by))) unname(join_by) else NULL,
                            all.x = TRUE)

    cat("\n")
  }

  # Summary
  cli_h2("Chain Summary")
  total_issues <- sum(vapply(results, function(r) length(r$report$issues), integer(1)))

  if (total_issues == 0) {
    cli_alert_success("No issues detected in join chain")
  } else {
    cli_alert_warning("Total issues across chain: {.val {total_issues}}")
  }

  invisible(results)
}

#' Detect Join Relationship Type
#'
#' Determines the actual cardinality relationship between two tables.
#'
#' @param x A data frame (left table).
#' @param y A data frame (right table).
#' @param by Column names to join by.
#'
#' @return Character string: "1:1", "1:m", "m:1", or "m:m".
#'
#' @examples
#' # 1:1 relationship
#' x <- data.frame(id = 1:3, val = 1:3)
#' y <- data.frame(id = 1:3, name = c("A", "B", "C"))
#' detect_cardinality(x, y, "id")
#'
#' # 1:m relationship
#' x <- data.frame(id = 1:3, val = 1:3)
#' y <- data.frame(id = c(1, 1, 2, 3), name = c("A1", "A2", "B", "C"))
#' detect_cardinality(x, y, "id")
#'
#' @seealso [join_strict()], [join_spy()]
#' @export
detect_cardinality <- function(x, y, by) {
  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Handle named by vector
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  x_summary <- .summarize_keys(x, x_by)
  y_summary <- .summarize_keys(y, y_by)

  x_has_dups <- x_summary$n_duplicates > 0
  y_has_dups <- y_summary$n_duplicates > 0

  cardinality <- if (x_has_dups && y_has_dups) {
    "m:m"
  } else if (x_has_dups) {
    "m:1"
  } else if (y_has_dups) {
    "1:m"
  } else {
    "1:1"
  }

  cli_alert_info("Detected cardinality: {.val {cardinality}}")

  if (x_summary$n_duplicates > 0) {
    cli_text("  Left duplicates: {.val {x_summary$n_duplicates}} key(s)")
  }
  if (y_summary$n_duplicates > 0) {
    cli_text("  Right duplicates: {.val {y_summary$n_duplicates}} key(s)")
  }

  invisible(cardinality)
}
