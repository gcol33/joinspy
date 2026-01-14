# =============================================================================
# Cardinality-Enforcing Joins
# =============================================================================

#' Strict Join with Cardinality Enforcement
#'
#' Performs a join operation that fails if the specified cardinality constraint
#' is violated. Use this to catch unexpected many-to-many relationships early.
#'
#' @param x A data frame (left table).
#' @param y A data frame (right table).
#' @param by A character vector of column names to join by.
#' @param type Character. The type of join to perform. One of `"left"` (default),
#'   `"right"`, `"inner"`, `"full"`.
#' @param expect Character. The expected cardinality relationship. One of:
#' \describe{
#'   \item{"1:1"}{Each key in x matches at most one key in y, and vice versa}
#'   \item{"1:m" or "1:many"}{Each key in x can match multiple keys in y,
#'     but each key in y matches at most one key in x}
#'   \item{"m:1" or "many:1"}{Each key in y can match multiple keys in x,
#'     but each key in x matches at most one key in y}
#'   \item{"m:m" or "many:many"}{No cardinality constraints (allows all relationships)}
#' }
#' @param ... Additional arguments passed to the underlying join function.
#'
#' @return The joined data frame if the cardinality constraint is satisfied.
#'   Throws an error if the constraint is violated.
#'
#' @examples
#' orders <- data.frame(id = 1:3, product = c("A", "B", "C"))
#' customers <- data.frame(id = 1:3, name = c("Alice", "Bob", "Carol"))
#'
#' # This succeeds (1:1 relationship)
#' join_strict(orders, customers, by = "id", expect = "1:1")
#'
#' # This would fail if customers had duplicate ids
#' \dontrun{
#' customers_dup <- data.frame(id = c(1, 1, 2), name = c("A1", "A2", "B"))
#' join_strict(orders, customers_dup, by = "id", expect = "1:1")
#' # Error: Expected 1:1 relationship but found 1:many
#' }
#'
#' @seealso [join_spy()], [left_join_spy()]
#' @export
join_strict <- function(x, y, by, type = c("left", "right", "inner", "full"),
                        expect = c("1:1", "1:m", "1:many", "m:1", "many:1", "m:m", "many:many"),
                        ...) {
  type <- match.arg(type)
  expect <- match.arg(expect)

  # Validate inputs
  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Handle named by vector
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

  # Get key summaries to check cardinality
  x_summary <- .summarize_keys(x, x_by)
  y_summary <- .summarize_keys(y, y_by)

  x_has_dups <- x_summary$n_duplicates > 0
  y_has_dups <- y_summary$n_duplicates > 0

  # Normalize expect
  expect_norm <- switch(
    expect,
    "1:many" = "1:m",
    "many:1" = "m:1",
    "many:many" = "m:m",
    expect
  )

  # Check cardinality constraint
  actual <- if (x_has_dups && y_has_dups) {
    "m:m"
  } else if (x_has_dups) {
    "m:1"
  } else if (y_has_dups) {
    "1:m"
  } else {
    "1:1"
  }

  # Determine if constraint is satisfied
  # 1:1 is the most restrictive, m:m is the least
  cardinality_levels <- c("1:1" = 1, "1:m" = 2, "m:1" = 2, "m:m" = 3)

  actual_level <- cardinality_levels[actual]
  expect_level <- cardinality_levels[expect_norm]

  # Special handling for 1:m vs m:1 (they're incompatible with each other)
  violates <- FALSE
  if (expect_norm == "1:1" && actual != "1:1") {
    violates <- TRUE
  } else if (expect_norm == "1:m" && x_has_dups) {
    violates <- TRUE
  } else if (expect_norm == "m:1" && y_has_dups) {
    violates <- TRUE
  }
  # m:m allows everything

  if (violates) {
    stop(sprintf(
      "Cardinality violation: expected %s but found %s\n\t Left duplicates: %d, Right duplicates: %d",
      expect, actual, x_summary$n_duplicates, y_summary$n_duplicates
    ), call. = FALSE)
  }

  # Perform the join using base R merge
  all_x <- type %in% c("left", "full")
  all_y <- type %in% c("right", "full")

  # Build by argument for merge
  if (is.null(names(by))) {
    result <- merge(x, y, by = by, all.x = all_x, all.y = all_y, ...)
  } else {
    result <- merge(x, y, by.x = x_by, by.y = y_by, all.x = all_x, all.y = all_y, ...)
  }

  result
}
