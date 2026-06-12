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
#'   \item{"1:n" or "1:many"}{Each key in x can match multiple keys in y,
#'     but each key in y matches at most one key in x}
#'   \item{"n:1" or "many:1"}{Each key in y can match multiple keys in x,
#'     but each key in x matches at most one key in y}
#'   \item{"n:m" or "many:many"}{No cardinality constraints (allows all relationships)}
#' }
#' @param backend Character or `NULL`. The join backend to use. If `NULL`
#'   (default), auto-detects from input class. See [left_join_spy()] for details.
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
#' # This fails if customers had duplicate ids (wrapped in try to show error)
#' customers_dup <- data.frame(id = c(1, 1, 2), name = c("A1", "A2", "B"))
#' try(join_strict(orders, customers_dup, by = "id", expect = "1:1"))
#'
#' @seealso [join_spy()], [left_join_spy()]
#' @export
join_strict <- function(x, y, by, type = c("left", "right", "inner", "full"),
                        expect = c("1:1", "1:n", "1:many", "n:1", "many:1", "n:m", "many:many"),
                        backend = NULL, ...) {
  type <- match.arg(type)
  expect <- match.arg(expect)

  # Validate inputs
  .validate_df(x, "x")
  .validate_df(y, "y")

  # Handle named by vector
  resolved <- .resolve_by(by)
  x_by <- resolved$x
  y_by <- resolved$y

  # Check columns exist
  .check_cols(x, x_by, "x")
  .check_cols(y, y_by, "y")

  # Get key summaries to check cardinality
  x_summary <- .summarize_keys(x, x_by)
  y_summary <- .summarize_keys(y, y_by)

  x_has_dups <- x_summary$n_duplicates > 0
  y_has_dups <- y_summary$n_duplicates > 0

  # Normalize expect
  expect_norm <- switch(
    expect,
    "1:many" = "1:n",
    "many:1" = "n:1",
    "many:many" = "n:m",
    expect
  )

  # Check cardinality constraint
  actual <- .classify_cardinality(x_has_dups, y_has_dups)

  # Special handling for 1:n vs n:1 (they're incompatible with each other)
  violates <- FALSE
  if (expect_norm == "1:1" && actual != "1:1") {
    violates <- TRUE
  } else if (expect_norm == "1:n" && x_has_dups) {
    violates <- TRUE
  } else if (expect_norm == "n:1" && y_has_dups) {
    violates <- TRUE
  }
  # n:m allows everything

  if (violates) {
    cli_abort(c(
      "Cardinality violation: expected {.val {expect}} but found {.val {actual}}.",
      "i" = "Left duplicates: {.val {x_summary$n_duplicates}}, right duplicates: {.val {y_summary$n_duplicates}}."
    ))
  }

  # Perform the join via backend dispatch
  .perform_join(x, y, by, type, backend = backend, ...)
}
