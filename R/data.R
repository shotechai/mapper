# CSV fields are initially character strings so geography codes keep leading zeros.
read_indicator_data <- function(path) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                 name_repair = "check_unique", show_col_types = FALSE)
}

# Join without silently multiplying features. Data must have one row per code;
# boundary codes must also identify one feature each. The diagnostics are retained.
join_map_data <- function(boundaries, data, boundary_key, data_key) {
  if (!boundary_key %in% names(boundaries) || !data_key %in% names(data)) {
    stop("Choose valid geography-code columns in both inputs.")
  }
  if (any(grepl("^\\.map_", names(data)))) stop("CSV columns beginning .map_ are reserved.")
  b <- boundaries
  d <- as.data.frame(data)
  b[[boundary_key]] <- trimws(as.character(b[[boundary_key]]))
  d[[data_key]] <- trimws(as.character(d[[data_key]]))
  if (anyNA(b[[boundary_key]]) || any(!nzchar(b[[boundary_key]])) ||
      anyNA(d[[data_key]]) || any(!nzchar(d[[data_key]]))) stop("Geography codes cannot be blank.")
  if (anyDuplicated(b[[boundary_key]]) || anyDuplicated(d[[data_key]])) {
    stop("Duplicate geography codes: filter or aggregate to one row per area first.")
  }
  # Prefix data columns to prevent accidental collisions with boundary attributes.
  names(d)[names(d) != data_key] <- paste0("data_", names(d)[names(d) != data_key])
  collisions <- intersect(setdiff(names(d), data_key), names(b))
  if (length(collisions)) stop("Data column name collision: ", paste(collisions, collapse = ", "))
  matched <- b[[boundary_key]] %in% d[[data_key]]
  result <- dplyr::left_join(b, d, by = stats::setNames(data_key, boundary_key))
  list(map = result,
       summary = data.frame(boundary_features = nrow(b), matched = sum(matched),
                            without_data = sum(!matched),
                            unused_data = sum(!d[[data_key]] %in% b[[boundary_key]])),
       missing_codes = b[[boundary_key]][!matched],
       unused_codes = d[[data_key]][!d[[data_key]] %in% b[[boundary_key]]])
}

# Parse numeric values deliberately. Arbitrary text and symbols must be cleaned;
# missing values remain missing, while real zero remains zero.
numeric_indicator <- function(x) {
  if (is.numeric(x)) {
    if (any(!is.finite(x) & !is.na(x))) stop("Indicator contains infinite values.")
    return(x)
  }
  x <- trimws(as.character(x))
  missing <- is.na(x) | x == "" | toupper(x) == "NA"
  out <- suppressWarnings(as.numeric(x))
  if (any(!missing & (is.na(out) | !is.finite(out)))) {
    stop("Indicator must contain numbers only; remove commas, % signs and suppression text first.")
  }
  out[missing] <- NA_real_
  out
}

# Interpret percentage indicators consistently without changing the source data.
# Raw values remain untouched; fractional percentages are converted to 0--100.
scale_indicator_values <- function(x, value_scale = "raw") {
  values <- numeric_indicator(x)
  if (!value_scale %in% c("raw", "fraction_percent")) {
    stop("Choose values as entered or fractional percentages.")
  }
  if (value_scale == "fraction_percent") {
    if (any(values < 0 | values > 1, na.rm = TRUE)) {
      stop("Fractional percentages must be between 0 and 1 (for example 0.2 for 20%).")
    }
    values <- values * 100
  }
  values
}

# Calculate percentages from counts. Zero or missing denominators give NA.
# Invalid negative counts or numerators above denominators are rejected.
calculate_percentage <- function(numerator, denominator) {
  if (length(numerator) != length(denominator)) stop("Numerator and denominator must have the same length.")
  n <- numeric_indicator(numerator)
  d <- numeric_indicator(denominator)
  if (any(n < 0 | d < 0 | n > d, na.rm = TRUE)) stop("Percentage counts must satisfy 0 <= numerator <= denominator.")
  result <- rep(NA_real_, length(n))
  valid <- !is.na(n) & !is.na(d) & d > 0
  result[valid] <- 100 * n[valid] / d[valid]
  result
}
