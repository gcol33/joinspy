# =============================================================================
# Post-Join Diagnostics
# =============================================================================

#' Explain Row Count Changes After a Join
#'
#' After performing a join, use this function to understand why the row count
#' changed. It analyzes the original tables and the result to explain the
#' difference.
#'
#' @param result The result of a join operation.
#' @param x The original left data frame.
#' @param y The original right data frame.
#' @param by A character vector of column names used in the join.
#' @param type Character. The type of join that was performed. One of
#'   `"left"`, `"right"`, `"inner"`, `"full"`. If `NULL` (default),
#'   attempts to infer the join type from row counts.
#'
#' @return Invisibly returns a list with explanation details. Prints a
#'   human-readable explanation.
#'
#' @examples
#' orders <- data.frame(id = c(1, 2, 2, 3), value = 1:4)
#' customers <- data.frame(id = c(1, 2, 2, 4), name = c("A", "B1", "B2", "D"))
#'
#' result <- merge(orders, customers, by = "id", all.x = TRUE)
#'
#' # Explain why we got more rows than expected
#' join_explain(result, orders, customers, by = "id", type = "left")
#'
#' @seealso [join_spy()], [join_diff()]
#' @export
join_explain <- function(result, x, y, by, type = NULL) {
  # TODO: Implement
  stop("Not yet implemented", call. = FALSE)
}


#' Compare Data Frame Before and After Join
#'
#' Shows a side-by-side comparison of key statistics before and after a join
#' operation.
#'
#' @param before The original data frame (before joining).
#' @param after The result data frame (after joining).
#' @param by Optional. Column names to analyze for key statistics.
#'
#' @return Invisibly returns a comparison summary. Prints a formatted comparison.
#'
#' @examples
#' before <- data.frame(id = 1:3, x = letters[1:3])
#' after <- data.frame(id = c(1, 2, 2, 3), x = c("a", "b", "b", "c"), y = 1:4
#' )
#'
#' join_diff(before, after)
#'
#' @seealso [join_explain()], [join_spy()]
#' @export
join_diff <- function(before, after, by = NULL) {
  # TODO: Implement
  stop("Not yet implemented", call. = FALSE)
}
