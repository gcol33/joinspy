# =============================================================================
# String Diagnostic Utilities
# =============================================================================

#' Detect Whitespace Issues in Keys
#'
#' Checks for leading or trailing whitespace in character vectors.
#'
#' @param x A character vector to check.
#' @return A list with:
#' \describe{
#'   \item{has_issues}{Logical indicating if whitespace issues found}
#'   \item{leading}{Indices of values with leading whitespace}
#'   \item{trailing}{Indices of values with trailing whitespace}
#'   \item{affected_values}{Unique values with whitespace issues}
#' }
#' @keywords internal
.detect_whitespace <- function(x) {
  if (!is.character(x)) {
    return(list(
      has_issues = FALSE,
      leading = integer(0),
      trailing = integer(0),
      affected_values = character(0)
    ))
  }

  leading <- which(grepl("^\\s+", x))
  trailing <- which(grepl("\\s+$", x))
  affected_idx <- unique(c(leading, trailing))

  list(
    has_issues = length(affected_idx) > 0,
    leading = leading,
    trailing = trailing,
    affected_values = unique(x[affected_idx])
  )
}

#' Detect Case Mismatches Between Keys
#'
#' Finds keys that would match if case-insensitive but don't match case-sensitive.
#'
#' @param x A character vector (keys from left table).
#' @param y A character vector (keys from right table).
#' @return A list with:
#' \describe{
#'   \item{has_issues}{Logical indicating if case mismatches found}
#'   \item{mismatches}{Data frame of key pairs that differ only by case}
#' }
#' @keywords internal
.detect_case_mismatch <- function(x, y) {
  if (!is.character(x) || !is.character(y)) {
    return(list(has_issues = FALSE, mismatches = data.frame()))
  }

  x_unique <- unique(x[!is.na(x)])
  y_unique <- unique(y[!is.na(y)])

  # Find keys in x that don't match y exactly but would match case-insensitively
  x_lower <- tolower(x_unique)
  y_lower <- tolower(y_unique)

  # Keys in x that have no exact match but have case-insensitive match
  no_exact <- x_unique[!x_unique %in% y_unique]
  has_case_match <- no_exact[x_lower[!x_unique %in% y_unique] %in% y_lower]

  if (length(has_case_match) == 0) {
    return(list(has_issues = FALSE, mismatches = data.frame()))
  }

  # Build mismatch pairs
  mismatches <- lapply(has_case_match, function(key) {
    y_matches <- y_unique[tolower(y_unique) == tolower(key)]
    data.frame(
      x_key = key,
      y_key = y_matches,
      stringsAsFactors = FALSE
    )
  })
  mismatches <- do.call(rbind, mismatches)

  list(
    has_issues = TRUE,
    mismatches = mismatches
  )
}

#' Detect Encoding Issues in Keys
#'
#' Checks for encoding inconsistencies and invisible Unicode characters.
#'
#' @param x A character vector to check.
#' @return A list with:
#' \describe{
#'   \item{has_issues}{Logical indicating if encoding issues found}
#'   \item{mixed_encoding}{Logical if multiple encodings detected}
#'   \item{invisible_chars}{Indices of values with invisible Unicode}
#'   \item{affected_values}{Values with encoding issues}
#' }
#' @keywords internal
.detect_encoding_issues <- function(x) {
  if (!is.character(x)) {
    return(list(
      has_issues = FALSE,
      mixed_encoding = FALSE,
      invisible_chars = integer(0),
      affected_values = character(0)
    ))
  }

  # Check for mixed encodings
  encodings <- Encoding(x)
  mixed <- length(unique(encodings[encodings != "unknown"])) > 1


  # Check for invisible Unicode characters (zero-width spaces, etc.)
  # Common invisible characters:
  # \u200B zero-width space
  # \u200C zero-width non-joiner
  # \u200D zero-width joiner
  # \uFEFF byte order mark
  # \u00A0 non-breaking space (looks like space but isn't)
  invisible_pattern <- "[\u200B\u200C\u200D\uFEFF\u00A0]"
  invisible_idx <- which(grepl(invisible_pattern, x, perl = TRUE))

  has_issues <- mixed || length(invisible_idx) > 0

  list(
    has_issues = has_issues,
    mixed_encoding = mixed,
    invisible_chars = invisible_idx,
    affected_values = if (length(invisible_idx) > 0) unique(x[invisible_idx]) else character(0)
  )
}

#' Summarize Key Column
#'
#' Creates a summary of a key column or composite key.
#'
#' @param data A data frame.
#' @param by Column name(s) to summarize.
#' @return A list with summary statistics.
#' @keywords internal
.summarize_keys <- function(data, by) {
  n_rows <- nrow(data)


  # Create composite key if multiple columns
  if (length(by) == 1) {
    keys <- data[[by]]
  } else {
    keys <- do.call(paste, c(data[by], sep = "\x1F"))
  }

  n_na <- sum(is.na(keys))
  keys_no_na <- keys[!is.na(keys)]
  n_unique <- length(unique(keys_no_na))

  # Count duplicates (keys appearing more than once)
  key_counts <- table(keys_no_na)
  dup_keys <- names(key_counts[key_counts > 1])
  n_dup_keys <- length(dup_keys)
  n_dup_rows <- sum(key_counts[key_counts > 1])

  list(
    n_rows = n_rows,
    n_unique = n_unique,
    n_duplicates = n_dup_keys,
    n_duplicate_rows = n_dup_rows,
    n_na = n_na,
    duplicate_keys = dup_keys
  )
}

#' Analyze Match Between Two Key Sets
#'
#' Compares keys from two tables to determine overlap.
#'
#' @param x_keys Vector of keys from left table (NA removed).
#' @param y_keys Vector of keys from right table (NA removed).
#' @param x_n_rows Total rows in left table.
#' @return A list with match analysis.
#' @keywords internal
.analyze_match <- function(x_keys, y_keys, x_n_rows) {
  x_unique <- unique(x_keys[!is.na(x_keys)])
  y_unique <- unique(y_keys[!is.na(y_keys)])

  matched <- intersect(x_unique, y_unique)
  left_only <- setdiff(x_unique, y_unique)
  right_only <- setdiff(y_unique, x_unique)

  # Match rate: proportion of left table keys that have a match
  match_rate <- if (length(x_unique) > 0) {
    length(matched) / length(x_unique)
  } else {
    NA_real_
  }

  list(
    n_matched = length(matched),
    n_left_only = length(left_only),
    n_right_only = length(right_only),
    match_rate = match_rate,
    matched_keys = matched,
    left_only_keys = left_only,
    right_only_keys = right_only
  )
}

#' Predict Row Counts for Different Join Types
#'
#' Estimates the number of rows that will result from different join types.
#'
#' @param x A data frame (left table).
#' @param y A data frame (right table).
#' @param by Column names to join by.
#' @return A list with predicted row counts.
#' @keywords internal
.predict_row_counts <- function(x, y, by) {
  # Get keys
  x_by <- if (is.null(names(by))) by else names(by)
  y_by <- if (is.null(names(by))) by else unname(by)

  if (length(x_by) == 1) {
    x_keys <- x[[x_by]]
    y_keys <- y[[y_by]]
  } else {
    x_keys <- do.call(paste, c(x[x_by], sep = "\x1F"))
    y_keys <- do.call(paste, c(y[y_by], sep = "\x1F"))
  }

  # Count occurrences
  x_counts <- table(x_keys[!is.na(x_keys)])
  y_counts <- table(y_keys[!is.na(y_keys)])

  # Matched keys
  matched_keys <- intersect(names(x_counts), names(y_counts))


  # Inner join: sum of products of counts for matching keys
  inner <- sum(vapply(matched_keys, function(k) {
    as.numeric(x_counts[k]) * as.numeric(y_counts[k])
  }, numeric(1)))

  # Left join: inner + unmatched left rows
  x_unmatched <- sum(is.na(x_keys)) + sum(x_counts[!names(x_counts) %in% matched_keys])
  left <- inner + x_unmatched

  # Right join: inner + unmatched right rows
  y_unmatched <- sum(is.na(y_keys)) + sum(y_counts[!names(y_counts) %in% matched_keys])
  right <- inner + y_unmatched

  # Full join: inner + both unmatched

  full <- inner + x_unmatched + y_unmatched

  list(
    inner = as.integer(inner),
    left = as.integer(left),
    right = as.integer(right),
    full = as.integer(full)
  )
}

# =============================================================================
# Phase 2: Enhanced Detection Utilities
# =============================================================================

#' Detect Type Mismatches Between Key Columns
#'
#' Checks if key columns have compatible types for joining.
#'
#' @param x_col Column from left table.
#' @param y_col Column from right table.
#' @param x_name Name of left column.
#' @param y_name Name of right column.
#' @return A list with type mismatch information.
#' @keywords internal
.detect_type_mismatch <- function(x_col, y_col, x_name, y_name) {
  x_class <- class(x_col)[1]
  y_class <- class(y_col)[1]

  issues <- list()

 # Character vs factor
  if ((x_class == "character" && y_class == "factor") ||
      (x_class == "factor" && y_class == "character")) {
    issues <- c(issues, list(list(
      type = "type_mismatch",
      severity = "info",
      message = sprintf(
        "Type difference: '%s' is %s, '%s' is %s (will be coerced)",
        x_name, x_class, y_name, y_class
      )
    )))
  }

  # Numeric vs character (potential issue)
  if ((is.numeric(x_col) && is.character(y_col)) ||
      (is.character(x_col) && is.numeric(y_col))) {
    issues <- c(issues, list(list(
      type = "type_mismatch",
      severity = "warning",
      message = sprintf(
        "Type mismatch: '%s' is %s, '%s' is %s - may cause unexpected results",
        x_name, x_class, y_name, y_class
      )
    )))
  }

  # Integer vs double (usually fine but worth noting for large numbers)
  if ((x_class == "integer" && y_class == "numeric") ||
      (x_class == "numeric" && y_class == "integer")) {
    # Check for potential precision issues with large integers
    if (is.numeric(x_col)) {
      max_val <- max(abs(x_col), na.rm = TRUE)
      if (!is.na(max_val) && max_val > 2^53) {
        issues <- c(issues, list(list(
          type = "precision",
          severity = "warning",
          message = sprintf(
            "Large numeric values in '%s' may lose precision",
            x_name
          )
        )))
      }
    }
  }

  list(
    has_issues = length(issues) > 0,
    issues = issues
  )
}

#' Detect Factor Level Mismatches
#'
#' Checks if factor columns have mismatched levels.
#'
#' @param x_col Factor column from left table.
#' @param y_col Factor column from right table.
#' @param x_name Name of left column.
#' @param y_name Name of right column.
#' @return A list with factor mismatch information.
#' @keywords internal
.detect_factor_mismatch <- function(x_col, y_col, x_name, y_name) {
  if (!is.factor(x_col) || !is.factor(y_col)) {
    return(list(has_issues = FALSE, issues = list()))
  }

  x_levels <- levels(x_col)
  y_levels <- levels(y_col)

  # Levels in x but not y
  x_only <- setdiff(x_levels, y_levels)
  # Levels in y but not x
  y_only <- setdiff(y_levels, x_levels)

  issues <- list()

  if (length(x_only) > 0 || length(y_only) > 0) {
    msg_parts <- character(0)
    if (length(x_only) > 0) {
      msg_parts <- c(msg_parts, sprintf(
        "%d level(s) only in '%s'",
        length(x_only), x_name
      ))
    }
    if (length(y_only) > 0) {
      msg_parts <- c(msg_parts, sprintf(
        "%d level(s) only in '%s'",
        length(y_only), y_name
      ))
    }

    issues <- c(issues, list(list(
      type = "factor_levels",
      severity = "info",
      message = paste("Factor level mismatch:", paste(msg_parts, collapse = ", ")),
      x_only_levels = x_only,
      y_only_levels = y_only
    )))
  }

  list(
    has_issues = length(issues) > 0,
    issues = issues
  )
}

#' Detect Empty Strings in Keys
#'
#' Checks for empty strings which behave differently from NA in joins.
#'
#' @param x A character vector to check.
#' @return A list with empty string detection results.
#' @keywords internal
.detect_empty_strings <- function(x) {
  if (!is.character(x)) {
    return(list(
      has_issues = FALSE,
      n_empty = 0,
      indices = integer(0)
    ))
  }

  empty_idx <- which(x == "" & !is.na(x))

  list(
    has_issues = length(empty_idx) > 0,
    n_empty = length(empty_idx),
    indices = empty_idx
  )
}

#' Detect Numeric Precision Issues
#'
#' Checks for floating-point keys that may not match exactly.
#'
#' @param x A numeric vector to check.
#' @return A list with precision issue detection results.
#' @keywords internal
.detect_numeric_precision <- function(x) {
  if (!is.numeric(x) || is.integer(x)) {
    return(list(has_issues = FALSE, issues = list()))
  }

  issues <- list()

 # Check for non-integer doubles (potential floating-point comparison issues)
  non_na <- x[!is.na(x)]
  if (length(non_na) > 0) {
    has_decimals <- any(non_na != floor(non_na))
    if (has_decimals) {
      issues <- c(issues, list(list(
        type = "float_precision",
        severity = "warning",
        message = "Floating-point key values may not match exactly due to precision"
      )))
    }

    # Check for very large numbers
    max_val <- max(abs(non_na), na.rm = TRUE)
    if (!is.na(max_val) && max_val > 2^53) {
      issues <- c(issues, list(list(
        type = "large_numeric",
        severity = "warning",
        message = "Very large numeric values may lose precision"
      )))
    }
  }

  list(
    has_issues = length(issues) > 0,
    issues = issues
  )
}

#' Calculate 'Levenshtein' Distance
#'
#' Simple implementation for detecting near-matches.
#'
#' @param s1 First string.
#' @param s2 Second string.
#' @return Integer distance.
#' @keywords internal
.levenshtein <- function(s1, s2) {
  if (s1 == s2) return(0L)

  n1 <- nchar(s1)
  n2 <- nchar(s2)

  if (n1 == 0) return(n2)
  if (n2 == 0) return(n1)

  # Use R's built-in adist for efficiency
  as.integer(adist(s1, s2)[1, 1])
}

#' Detect Near-Matches Between Keys
#'
#' Finds keys that almost match (small edit distance).
#'
#' @param x_keys Unique keys from left table.
#' @param y_keys Unique keys from right table.
#' @param max_distance Maximum 'Levenshtein' distance to consider a near-match.
#' @param max_candidates Maximum number of near-match candidates to return.
#' @return A list with near-match information.
#' @keywords internal
.detect_near_matches <- function(x_keys, y_keys, max_distance = 2, max_candidates = 10) {
  if (!is.character(x_keys) || !is.character(y_keys)) {
    return(list(has_issues = FALSE, near_matches = data.frame()))
  }

  # Only look at unmatched keys
  x_unmatched <- setdiff(x_keys, y_keys)
  x_unmatched <- x_unmatched[!is.na(x_unmatched)]

  if (length(x_unmatched) == 0 || length(y_keys) == 0) {
    return(list(has_issues = FALSE, near_matches = data.frame()))
  }

  y_unique <- unique(y_keys[!is.na(y_keys)])

  # Limit search for performance
  x_sample <- head(x_unmatched, 50)
  y_sample <- head(y_unique, 100)

  near_matches <- data.frame(
    x_key = character(0),
    y_key = character(0),
    distance = integer(0),
    stringsAsFactors = FALSE
  )

  for (x_key in x_sample) {
    # Skip very short strings (too many false positives)
    if (nchar(x_key) < 3) next

    for (y_key in y_sample) {
      # Quick length check to skip obviously different strings
      len_diff <- abs(nchar(x_key) - nchar(y_key))
      if (len_diff > max_distance) next

      dist <- .levenshtein(x_key, y_key)
      if (dist > 0 && dist <= max_distance) {
        near_matches <- rbind(near_matches, data.frame(
          x_key = x_key,
          y_key = y_key,
          distance = dist,
          stringsAsFactors = FALSE
        ))
      }
    }

    if (nrow(near_matches) >= max_candidates) break
  }

  # Sort by distance
  if (nrow(near_matches) > 0) {
    near_matches <- near_matches[order(near_matches$distance), ]
    near_matches <- head(near_matches, max_candidates)
  }

  list(
    has_issues = nrow(near_matches) > 0,
    near_matches = near_matches
  )
}

#' Analyze Multi-Column Key Breakdown
#'
#' For composite keys, determines which column(s) cause mismatches.
#'
#' @param x Data frame (left table).
#' @param y Data frame (right table).
#' @param x_by Column names in x.
#' @param y_by Column names in y.
#' @return A list with per-column match analysis.
#' @keywords internal
.analyze_multicolumn_keys <- function(x, y, x_by, y_by) {
  if (length(x_by) < 2) {
    return(list(is_multicolumn = FALSE, column_analysis = list()))
  }

  column_analysis <- list()

  for (i in seq_along(x_by)) {
    x_col <- x_by[i]
    y_col <- y_by[i]

    x_vals <- unique(x[[x_col]][!is.na(x[[x_col]])])
    y_vals <- unique(y[[y_col]][!is.na(y[[y_col]])])

    matched <- length(intersect(x_vals, y_vals))
    x_only <- length(setdiff(x_vals, y_vals))
    y_only <- length(setdiff(y_vals, x_vals))

    column_analysis[[x_col]] <- list(
      x_column = x_col,
      y_column = y_col,
      x_unique = length(x_vals),
      y_unique = length(y_vals),
      matched = matched,
      x_only = x_only,
      y_only = y_only,
      match_rate = if (length(x_vals) > 0) matched / length(x_vals) else NA_real_
    )
  }

  # Identify the "problem" column (lowest match rate)
  match_rates <- vapply(column_analysis, function(ca) ca$match_rate, numeric(1))
  problem_col <- if (any(!is.na(match_rates))) {
    names(which.min(match_rates))
  } else {
    NULL
  }

  list(
    is_multicolumn = TRUE,
    column_analysis = column_analysis,
    problem_column = problem_col
  )
}
