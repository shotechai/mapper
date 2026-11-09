# Create map-ready Thurrock population examples from official Census 2021 data.
# LSOA values are direct TS007A records. Ward values sum OA records allocated by
# point-on-surface to the May 2026 ward polygons. Age 15 is estimated as one fifth
# of the published 15-19 band because exact single-year data are unavailable at
# OA/LSOA level. Outputs clearly retain this status and method.
source("R/load.R")

council_id <- "thurrock"
profile <- get_council_profile(council_id)
map_dir <- council_map_dir(council_id)
output_dir <- council_indicator_dir(council_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

source_url <- "https://www.nomisweb.co.uk/output/census/2021/census2021-ts007a.zip"
source_page <- "https://www.nomisweb.co.uk/datasets/c2021ts007a"
archive <- tempfile(fileext = ".zip")
on.exit(unlink(archive), add = TRUE)
utils::download.file(source_url, archive, mode = "wb", method = "libcurl", quiet = TRUE)

read_age_file <- function(member) {
  readr::read_csv(unz(archive, member), show_col_types = FALSE)
}
calculate_age_fields <- function(x) {
  age_0_14 <- x[["Age: Aged 4 years and under"]] +
    x[["Age: Aged 5 to 9 years"]] + x[["Age: Aged 10 to 14 years"]]
  age_15 <- x[["Age: Aged 15 to 19 years"]] / 5
  data.frame(population_2021 = x[["Age: Total"]], age_0_14 = age_0_14,
             age_15_estimate = age_15, stringsAsFactors = FALSE)
}

slug <- profile$slug
lsoa_layer <- paste0(slug, "_lsoa_2021")
oa_layer <- paste0(slug, "_oa_2021")
ward_layer <- paste0(slug, "_wards_2026")
lsoa <- load_map_layer(file.path(map_dir, paste0(lsoa_layer, ".gpkg")), lsoa_layer)
oa <- load_map_layer(file.path(map_dir, paste0(oa_layer, ".gpkg")), oa_layer)
wards <- load_map_layer(file.path(map_dir, paste0(ward_layer, ".gpkg")), ward_layer)

# Direct LSOA records from the official small-area table.
lsoa_source <- read_age_file("census2021-ts007a-lsoa.csv")
lsoa_source <- lsoa_source[lsoa_source[["geography code"]] %in% lsoa$LSOA21CD, , drop = FALSE]
if (nrow(lsoa_source) != nrow(lsoa)) stop("Not every LSOA boundary matched TS007A.")
lsoa_age <- calculate_age_fields(lsoa_source)
lsoa_result <- data.frame(
  area_code = lsoa_source[["geography code"]],
  area_name = lsoa_source$geography,
  lsoa_age,
  stringsAsFactors = FALSE
)
lsoa_result$age_15_estimated_count <- round(lsoa_result$age_15_estimate)
lsoa_result$age_0_15_estimated_count <- round(lsoa_result$age_0_14 + lsoa_result$age_15_estimate)
lsoa_result$age_0_15_estimated_pct <- round(
  100 * lsoa_result$age_0_15_estimated_count / lsoa_result$population_2021, 1)
lsoa_result$age_15_estimate <- NULL

# Allocate each real OA record to one ward, then aggregate its counts.
oa_source <- read_age_file("census2021-ts007a-oa.csv")
oa_source <- oa_source[oa_source[["geography code"]] %in% oa$OA21CD, , drop = FALSE]
if (nrow(oa_source) != nrow(oa)) stop("Not every OA boundary matched TS007A.")
ward_index <- sf::st_within(suppressWarnings(sf::st_point_on_surface(oa)), wards)
if (any(lengths(ward_index) != 1)) stop("Each OA must allocate to exactly one ward.")
oa_age <- calculate_age_fields(oa_source)
oa_values <- data.frame(
  oa_code = oa_source[["geography code"]],
  oa_age,
  stringsAsFactors = FALSE
)
oa_values <- dplyr::left_join(
  data.frame(oa_code = oa$OA21CD,
             area_code = wards$WD26CD[unlist(ward_index)],
             area_name = wards$WD26NM[unlist(ward_index)],
             stringsAsFactors = FALSE),
  oa_values, by = "oa_code")
if (anyNA(oa_values$population_2021)) stop("OA values did not align with OA boundaries.")
ward_result <- dplyr::summarise(
  dplyr::group_by(oa_values, area_code, area_name),
  population_2021 = sum(population_2021),
  age_0_14 = sum(age_0_14),
  age_15_estimate = sum(age_15_estimate),
  .groups = "drop")
ward_result$age_15_estimated_count <- round(ward_result$age_15_estimate)
ward_result$age_0_15_estimated_count <- round(ward_result$age_0_14 + ward_result$age_15_estimate)
ward_result$age_0_15_estimated_pct <- round(
  100 * ward_result$age_0_15_estimated_count / ward_result$population_2021, 1)
ward_result$age_15_estimate <- NULL

add_metadata <- function(x, geography_edition, status, method) {
  x$geography_edition <- geography_edition
  x$data_status <- status
  x$source_dataset <- "ONS Census 2021 TS007A - Age by five-year age bands"
  x$source_url <- source_page
  x$method_note <- method
  x
}
lsoa_result <- add_metadata(
  lsoa_result, "LSOA December 2021",
  "Official counts; age 15 estimated from published band",
  "Population and ages 0-14 are official LSOA counts. Age 15 is estimated as 20% of age 15-19.")
ward_result <- add_metadata(
  as.data.frame(ward_result), "Ward May 2026",
  "Derived from official OA counts; age 15 estimated",
  "Official OA counts assigned by point-on-surface to May 2026 wards; age 15 estimated as 20% of age 15-19.")

population_columns <- c("area_code", "area_name", "population_2021",
                        "geography_edition", "data_status", "source_dataset",
                        "source_url", "method_note")
percentage_columns <- c("area_code", "area_name", "population_2021",
                        "age_0_14", "age_15_estimated_count",
                        "age_0_15_estimated_count", "age_0_15_estimated_pct",
                        "geography_edition", "data_status", "source_dataset",
                        "source_url", "method_note")
outputs <- list(
  thurrock_wards_population_2021.csv = ward_result[population_columns],
  thurrock_lsoa_population_2021.csv = lsoa_result[population_columns],
  thurrock_wards_age_0_15_percentage_2021.csv = ward_result[percentage_columns],
  thurrock_lsoa_age_0_15_percentage_2021.csv = lsoa_result[percentage_columns]
)
for (name in names(outputs)) readr::write_csv(outputs[[name]], file.path(output_dir, name))

summary <- data.frame(
  file = names(outputs),
  rows = vapply(outputs, nrow, integer(1)),
  join_key = "area_code",
  stringsAsFactors = FALSE)
readr::write_csv(summary, file.path(output_dir, "indicator_manifest.csv"))
print(summary)
message("Population test data written to ", output_dir)
