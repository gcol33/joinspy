# =============================================================================
# Join Backend Dispatch
# =============================================================================

#' Detect the appropriate join backend from input classes
#'
#' @param x Left data frame.
#' @param y Right data frame.
#' @return Character: "data.table", "dplyr", or "base".
#' @keywords internal
.detect_backend <- function(x, y) {
  if (inherits(x, "data.table") || inherits(y, "data.table")) {
    if (!requireNamespace("data.table", quietly = TRUE)) {
      warning("data.table input detected but package not available, falling back to base R",
              call. = FALSE)
      return("base")
    }
    return("data.table")
  }

  if (inherits(x, "tbl_df") || inherits(y, "tbl_df")) {
    if (!requireNamespace("dplyr", quietly = TRUE)) {
      warning("tibble input detected but dplyr not available, falling back to base R",
              call. = FALSE)
      return("base")
    }
    return("dplyr")
  }

  "base"
}


#' Perform a join using the appropriate backend
#'
#' Single dispatch point for all join operations. Auto-detects the backend
#' from input classes, or uses an explicit override.
#'
#' @param x Left data frame.
#' @param y Right data frame.
#' @param by Column names (character vector, possibly named).
#' @param type Join type: "left", "right", "inner", or "full".
#' @param backend Character or NULL. If NULL (default), auto-detects from input
#'   class. Explicit values: "base", "dplyr", "data.table".
#' @param ... Additional arguments passed to the underlying join function.
#' @return The joined data frame, preserving the input class.
#' @keywords internal
.perform_join <- function(x, y, by, type, backend = NULL, ...) {
  backend <- backend %||% .detect_backend(x, y)

  switch(backend,
    "dplyr"      = .join_dplyr(x, y, by, type, ...),
    "data.table" = .join_data_table(x, y, by, type, ...),
    "base"       = .join_base(x, y, by, type, ...),
    cli_abort("Unknown backend: {.val {backend}}. Use {.val base}, {.val dplyr}, or {.val data.table}.")
  )
}


# -- Base R backend -----------------------------------------------------------

.join_base <- function(x, y, by, type, ...) {
  all_x <- type %in% c("left", "full")
  all_y <- type %in% c("right", "full")

  resolved <- .resolve_by(by)
  merge(x, y,
        by.x = resolved$x, by.y = resolved$y,
        all.x = all_x, all.y = all_y, ...)
}


# -- dplyr backend ------------------------------------------------------------

.join_dplyr <- function(x, y, by, type, ...) {
  join_fn <- switch(type,
    "left"  = dplyr::left_join,
    "right" = dplyr::right_join,
    "inner" = dplyr::inner_join,
    "full"  = dplyr::full_join
  )

  join_fn(x, y, by = by, ...)
}


# -- data.table backend -------------------------------------------------------

.join_data_table <- function(x, y, by, type, ...) {
  # Convert to data.table if not already
  x_dt <- data.table::as.data.table(x)
  y_dt <- data.table::as.data.table(y)

  # Resolve column names
  resolved <- .resolve_by(by)
  x_by <- resolved$x
  y_by <- resolved$y

  # data.table merge uses on= with setnames approach for different column names
  if (!identical(x_by, y_by)) {
    # as.data.table() returns data.table input as-is, so copy before
    # renaming to keep the caller's y untouched
    if (data.table::is.data.table(y)) {
      y_dt <- data.table::copy(y_dt)
    }
    data.table::setnames(y_dt, y_by, x_by)
    on_cols <- x_by
  } else {
    on_cols <- x_by
  }

  result <- switch(type,
    "inner" = merge(x_dt, y_dt, by = on_cols, all = FALSE, ...),
    "left"  = merge(x_dt, y_dt, by = on_cols, all.x = TRUE, ...),
    "right" = merge(x_dt, y_dt, by = on_cols, all.y = TRUE, ...),
    "full"  = merge(x_dt, y_dt, by = on_cols, all = TRUE, ...)
  )

  result
}
