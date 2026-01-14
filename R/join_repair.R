# =============================================================================
# Phase 3: Auto-Fix & Repair Functions
# =============================================================================

#' Repair Common Key Issues
#'
#' Automatically fixes trivial join key issues like whitespace and case
#' mismatches. Returns the repaired data frame(s) with a summary of changes.
#'
#' @param x A data frame (left table).
#' @param y A data frame (right table). If NULL, only repairs x.
#' @param by A character vector of column names to repair.
#' @param trim_whitespace Logical. Trim leading/trailing whitespace. Default TRUE.
#' @param standardize_case Character. Standardize case to "lower", "upper", or
#'   NULL (no change). Default NULL.
#' @param remove_invisible Logical. Remove invisible Unicode characters. Default TRUE.
#' @param empty_to_na Logical. Convert empty strings to NA. Default FALSE.
#' @param dry_run Logical. If TRUE, only report what would be changed without
#'   modifying data. Default FALSE.
#'
#' @return If `y` is NULL, returns the repaired `x`. If both are provided,
#'   returns a list with `x` and `y`. In dry_run mode, returns a summary of
#'   proposed changes.
#'
#' @examples
#' # Data with whitespace issues
#' orders <- data.frame(
#'   id = c(" A", "B ", "C"),
#'   value = 1:3,
#'   stringsAsFactors = FALSE
#' )
#'
#' # Dry run to see what would change
#' join_repair(orders, by = "id", dry_run = TRUE)
#'
#' # Actually repair
#' orders_fixed <- join_repair(orders, by = "id")
#'
#' @seealso [join_spy()], [key_check()]
#' @export
join_repair <- function(x, y = NULL, by,
                        trim_whitespace = TRUE,
                        standardize_case = NULL,
                        remove_invisible = TRUE,
                        empty_to_na = FALSE,
                        dry_run = FALSE) {

  if (!is.data.frame(x)) stop("`x` must be a data frame", call. = FALSE)
  if (!is.null(y) && !is.data.frame(y)) stop("`y` must be a data frame", call. = FALSE)

  # Handle named by vector
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  # Check columns exist
  missing_x <- setdiff(x_by, names(x))
  if (length(missing_x) > 0) {
    stop("Column(s) not found in x: ", paste(missing_x, collapse = ", "), call. = FALSE)
  }
  if (!is.null(y)) {
    missing_y <- setdiff(y_by, names(y))
    if (length(missing_y) > 0) {
      stop("Column(s) not found in y: ", paste(missing_y, collapse = ", "), call. = FALSE)
    }
  }

  # Validate standardize_case
  if (!is.null(standardize_case) && !standardize_case %in% c("lower", "upper")) {
    stop("`standardize_case` must be 'lower', 'upper', or NULL", call. = FALSE)
  }

  # Track changes
  changes <- list()

  # Repair function for a single column
  repair_column <- function(col, col_name, table_name) {
    if (!is.character(col)) {
      return(list(col = col, n_changes = 0L, change_types = character(0)))
    }

    original <- col
    change_types <- character(0)
    n_changes <- 0L

    # Trim whitespace
    if (trim_whitespace) {
      new_col <- trimws(col)
      changed <- as.integer(sum(new_col != col, na.rm = TRUE))
      if (changed > 0L) {
        n_changes <- n_changes + changed
        change_types <- c(change_types, sprintf("trimmed whitespace (%d)", changed))
        col <- new_col
      }
    }

    # Standardize case
    if (!is.null(standardize_case)) {
      new_col <- if (standardize_case == "lower") tolower(col) else toupper(col)
      changed <- as.integer(sum(new_col != col, na.rm = TRUE))
      if (changed > 0L) {
        n_changes <- n_changes + changed
        change_types <- c(change_types, sprintf("%s case (%d)", standardize_case, changed))
        col <- new_col
      }
    }

    # Remove invisible characters
    if (remove_invisible) {
      invisible_pattern <- "[\u200B\u200C\u200D\uFEFF\u00A0]"
      new_col <- gsub(invisible_pattern, "", col, perl = TRUE)
      changed <- as.integer(sum(new_col != col, na.rm = TRUE))
      if (changed > 0L) {
        n_changes <- n_changes + changed
        change_types <- c(change_types, sprintf("removed invisible chars (%d)", changed))
        col <- new_col
      }
    }

    # Convert empty to NA
    if (empty_to_na) {
      empty_idx <- which(col == "" & !is.na(col))
      if (length(empty_idx) > 0L) {
        n_changes <- n_changes + as.integer(length(empty_idx))
        change_types <- c(change_types, sprintf("empty to NA (%d)", length(empty_idx)))
        col[empty_idx] <- NA_character_
      }
    }

    list(col = col, n_changes = n_changes, change_types = change_types)
  }

  # Repair x
  x_changes <- list()
  x_repaired <- x
  for (col_name in x_by) {
    result <- repair_column(x[[col_name]], col_name, "x")
    if (result$n_changes > 0) {
      x_changes[[col_name]] <- result
      if (!dry_run) {
        x_repaired[[col_name]] <- result$col
      }
    }
  }

  # Repair y if provided
  y_changes <- list()
  y_repaired <- y
  if (!is.null(y)) {
    for (i in seq_along(y_by)) {
      col_name <- y_by[i]
      result <- repair_column(y[[col_name]], col_name, "y")
      if (result$n_changes > 0) {
        y_changes[[col_name]] <- result
        if (!dry_run) {
          y_repaired[[col_name]] <- result$col
        }
      }
    }
  }

  # Report changes
  total_x_changes <- sum(vapply(x_changes, function(c) c$n_changes, integer(1)))
  total_y_changes <- sum(vapply(y_changes, function(c) c$n_changes, integer(1)))

  if (dry_run) {
    cli_h1("Repair Preview (Dry Run)")

    if (total_x_changes == 0 && total_y_changes == 0) {
      cli_alert_success("No repairs needed")
    } else {
      if (total_x_changes > 0) {
        cli_h2("Left table (x)")
        for (col_name in names(x_changes)) {
          changes_str <- paste(x_changes[[col_name]]$change_types, collapse = ", ")
          cli_alert_info("{.field {col_name}}: {changes_str}")
        }
      }
      if (total_y_changes > 0) {
        cli_h2("Right table (y)")
        for (col_name in names(y_changes)) {
          changes_str <- paste(y_changes[[col_name]]$change_types, collapse = ", ")
          cli_alert_info("{.field {col_name}}: {changes_str}")
        }
      }
    }

    return(invisible(list(
      x_changes = x_changes,
      y_changes = y_changes,
      total_changes = total_x_changes + total_y_changes
    )))
  }

  # Report actual changes
  if (total_x_changes > 0 || total_y_changes > 0) {
    cli_alert_success("Repaired {.val {total_x_changes + total_y_changes}} value(s)")
  }

  # Return repaired data
  if (is.null(y)) {
    return(x_repaired)
  } else {
    return(list(x = x_repaired, y = y_repaired))
  }
}

#' Suggest Repair Code
#'
#' Analyzes join issues and returns R code snippets to fix them.
#'
#' @param report A `JoinReport` object from [join_spy()].
#'
#' @return Character vector of R code snippets to fix detected issues.
#'
#' @examples
#' orders <- data.frame(id = c("A ", "B"), val = 1:2, stringsAsFactors = FALSE)
#' customers <- data.frame(id = c("a", "b"), name = c("Alice", "Bob"), stringsAsFactors = FALSE)
#'
#' report <- join_spy(orders, customers, by = "id")
#' suggest_repairs(report)
#'
#' @seealso [join_repair()], [join_spy()]
#' @export
suggest_repairs <- function(report) {
  if (!is_join_report(report)) {
    stop("`report` must be a JoinReport object", call. = FALSE)
  }

  suggestions <- character(0)

  for (issue in report$issues) {
    if (issue$type == "whitespace") {
      col <- issue$column
      tbl <- if (issue$table == "x") "x" else "y"
      suggestions <- c(suggestions, sprintf(
        '%s$%s <- trimws(%s$%s)',
        tbl, col, tbl, col
      ))
    } else if (issue$type == "case_mismatch") {
      col_x <- issue$column_x
      col_y <- issue$column_y
      suggestions <- c(suggestions, sprintf(
        '# Standardize case:\nx$%s <- tolower(x$%s)\ny$%s <- tolower(y$%s)',
        col_x, col_x, col_y, col_y
      ))
    } else if (issue$type == "empty_string") {
      col <- issue$column
      tbl <- if (issue$table == "x") "x" else "y"
      suggestions <- c(suggestions, sprintf(
        '%s$%s[%s$%s == ""] <- NA',
        tbl, col, tbl, col
      ))
    } else if (issue$type == "encoding") {
      col <- issue$column
      tbl <- if (issue$table == "x") "x" else "y"
      suggestions <- c(suggestions, sprintf(
        '# Remove invisible characters:\n%s$%s <- gsub("[\\u200B\\u200C\\u200D\\uFEFF\\u00A0]", "", %s$%s, perl = TRUE)',
        tbl, col, tbl, col
      ))
    }
  }

  if (length(suggestions) == 0) {
    cli_alert_success("No repairs suggested - data looks clean!")
    return(invisible(character(0)))
  }

  cli_h1("Suggested Repairs")
  for (s in suggestions) {
    cli_code(s)
    cat("\n")
  }

  invisible(suggestions)
}
