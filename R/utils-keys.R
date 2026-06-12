# =============================================================================
# Shared Key-Handling Helpers
# =============================================================================

#' Resolve a possibly-named `by` into left and right column names
#'
#' @param by Character vector of join columns, optionally named for joins where
#'   column names differ (e.g., `c(id = "customer_id")`).
#' @return A list with elements `x` (left columns) and `y` (right columns).
#' @keywords internal
.resolve_by <- function(by) {
  if (is.null(names(by))) {
    list(x = by, y = by)
  } else {
    list(x = names(by), y = unname(by))
  }
}

#' Validate that an object is a data frame
#'
#' @param x Object to check.
#' @param arg Argument name used in the error message.
#' @param call Environment to attribute the error to.
#' @return Invisibly, `x`.
#' @keywords internal
.validate_df <- function(x, arg, call = rlang::caller_env()) {
  if (!is.data.frame(x)) {
    cli_abort("{.arg {arg}} must be a data frame.", call = call)
  }
  invisible(x)
}

#' Check that columns exist in a data frame
#'
#' @param df Data frame to check.
#' @param cols Column names that must be present.
#' @param side Optional side label (`"x"` or `"y"`) for the error message.
#' @param call Environment to attribute the error to.
#' @return Invisibly, `cols`.
#' @keywords internal
.check_cols <- function(df, cols, side = NULL, call = rlang::caller_env()) {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    where <- if (is.null(side)) "" else paste0(" in ", side)
    cli_abort("Column(s) not found{where}: {.val {missing}}", call = call)
  }
  invisible(cols)
}

#' Build a single key vector from one or more columns
#'
#' For composite keys, components are pasted with a unit-separator. A row is
#' marked `NA` whenever any of its key components is `NA`, matching how joins
#' treat a missing key component as non-matching.
#'
#' @param data Data frame.
#' @param cols Column name(s) forming the key.
#' @return A vector of keys, `NA` where any component is `NA`.
#' @keywords internal
.make_key <- function(data, cols) {
  if (length(cols) == 1) {
    return(data[[cols]])
  }
  key <- do.call(paste, c(data[cols], sep = "\x1F"))
  na_any <- Reduce(`|`, lapply(data[cols], is.na))
  key[na_any] <- NA_character_
  key
}

#' Classify the cardinality relationship from per-side duplicate flags
#'
#' @param x_has_dups Logical: the left table has duplicate keys.
#' @param y_has_dups Logical: the right table has duplicate keys.
#' @return One of `"1:1"`, `"1:n"`, `"n:1"`, `"n:m"`.
#' @keywords internal
.classify_cardinality <- function(x_has_dups, y_has_dups) {
  if (x_has_dups && y_has_dups) {
    "n:m"
  } else if (x_has_dups) {
    "n:1"
  } else if (y_has_dups) {
    "1:n"
  } else {
    "1:1"
  }
}
