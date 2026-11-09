withr::local_dir(testthat::test_path("..", ".."))

# Small deterministic spatial fixtures exercise geography and data safeguards.
make_areas <- function() {
  extent <- sf::st_as_sfc(sf::st_bbox(c(xmin = 560000, ymin = 180000,
                                       xmax = 562000, ymax = 182000), crs = sf::st_crs(27700)))
  sf::st_sf(code = c("001", "002", "003", "004"),
             name = LETTERS[1:4], geometry = sf::st_make_grid(extent, n = c(2, 2)))
}

testthat::test_that("local GeoPackages expose multiple layers and align CRSs", {
  folder <- tempfile(); dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  path <- file.path(folder, "example.gpkg")
  areas <- make_areas()
  sf::st_write(areas, path, layer = "areas", quiet = TRUE)
  points <- sf::st_sf(name = areas$name, geometry = sf::st_transform(sf::st_centroid(sf::st_geometry(areas)), 4326))
  sf::st_write(points, path, layer = "points", quiet = TRUE)
  layers <- list_map_layers(folder)
  testthat::expect_setequal(layers$layer, c("areas", "points"))
  result <- load_map_layer(path, "points")
  testthat::expect_equal(sf::st_crs(result)$epsg, 27700)
  testthat::expect_equal(nrow(select_map_area(areas, "code", "001")), 1)
  testthat::expect_error(select_map_area(areas, "code", "unknown"), "No features")
})

testthat::test_that("joins retain zeros and report unmatched codes without duplicating areas", {
  areas <- make_areas()
  data <- data.frame(id = c("001", "002", "999"), value = c("0", "12", "5"))
  joined <- join_map_data(areas, data, "code", "id")
  testthat::expect_equal(nrow(joined$map), 4)
  testthat::expect_equal(joined$summary$matched, 2)
  testthat::expect_equal(joined$summary$without_data, 2)
  testthat::expect_equal(joined$unused_codes, "999")
  testthat::expect_equal(numeric_indicator(joined$map$data_value), c(0, 12, NA, NA))
  testthat::expect_error(join_map_data(areas, data[c(1, 1), ], "code", "id"), "Duplicate")
  testthat::expect_error(numeric_indicator(c("12%", "13")), "numbers only")
  testthat::expect_error(numeric_indicator(c(1, Inf)), "infinite")
})

testthat::test_that("percentage calculations handle absent denominators and reject impossible counts", {
  testthat::expect_equal(calculate_percentage(c(0, 5, 0, NA), c(10, 20, 0, 10)), c(0, 25, NA, NA))
  testthat::expect_error(calculate_percentage(11, 10), "numerator")
  testthat::expect_error(calculate_percentage(1:2, 10), "same length")
})

testthat::test_that("fractional percentage indicators are converted to a 0--100 scale", {
  testthat::expect_equal(scale_indicator_values(c("0.2", "0.3", NA), "fraction_percent"),
                         c(20, 30, NA))
  testthat::expect_equal(scale_indicator_values(c("20.5", "30"), "raw"), c(20.5, 30))
  testthat::expect_error(scale_indicator_values(c(0.2, 1.1), "fraction_percent"), "between 0 and 1")
})

testthat::test_that("text columns create categorical map colours", {
  areas <- make_areas()
  areas$ward <- c("Aveley", "Belhus", "Chadwell", NA)
  settings <- default_map_settings()
  settings$variable <- "ward"; settings$variable_type <- "Categorical"
  plot <- build_map(areas, settings = settings)
  testthat::expect_equal(levels(plot$layers[[1]]$data$.map_category),
                         c("Aveley", "Belhus", "Chadwell"))
  testthat::expect_equal(length(plot$scales$scales[[1]]$palette(3)), 3)
  settings$category_colours <- list(Aveley = "#112233", Chadwell = "#ABCDEF")
  testthat::expect_s3_class(build_map(areas, settings = settings), "ggplot")
  palette <- category_palette(c("Aveley", "Belhus", "Chadwell"), settings$category_colours)
  testthat::expect_equal(unname(palette[c("Aveley", "Chadwell")]), c("#112233", "#ABCDEF"))
  testthat::expect_error(category_palette("Aveley", list(Aveley = "blue")), "six-digit")
})

testthat::test_that("fixed breaks cannot silently hide out-of-range observations", {
  testthat::expect_error(classify_values(c(0, 105), "Fixed breaks", breaks = "0,50,100"), "cover")
  testthat::expect_error(classify_values(1:3, "Fixed breaks", breaks = "3,2,1"), "increasing")
  testthat::expect_equal(length(classify_values(c(0, 25, NA), "Quantiles")), 3)
})

testthat::test_that("spatial restriction and three report export formats work together", {
  areas <- make_areas()
  points <- sf::st_sf(name = areas$name[1], geometry = sf::st_centroid(sf::st_geometry(areas[1, ])))
  far <- sf::st_sf(name = "Outside", geometry = sf::st_sfc(sf::st_point(c(600000, 200000)), crs = 27700))
  testthat::expect_equal(nrow(restrict_overlay(rbind(points[, "name"], far), areas, "Intersecting features")), 1)
  areas$value <- c(0, 25, 50, NA)
  settings <- default_map_settings(); settings$variable <- "value"
  settings$labels <- TRUE; settings$label <- "name"
  overlay <- list(data = points, name = "Site", visible = TRUE, colour = "#000000",
                   size = 2, alpha = 1, shape = 16, outline_only = FALSE, label = "")
  outline <- list(data = areas[1, ], name = "Polygon outline", visible = TRUE,
                    colour = "#663399", size = 0.6, alpha = 1, shape = 16,
                    outline_only = TRUE, label = "")
  plot <- build_map(areas, list(outline, overlay), settings)
  clipped <- restrict_overlay(areas, areas[1, ], "Clip to base")
  testthat::expect_equal(nrow(clipped), 1)
  testthat::expect_equal(as.numeric(sum(sf::st_area(clipped))),
                          as.numeric(sf::st_area(areas[1, ])))
  for (format in c("png", "pdf", "jpg")) {
    file <- tempfile(fileext = paste0(".", format))
    export_map(plot, file, width = 4, height = 4, dpi = 100)
    testthat::expect_gt(file.info(file)$size, 100)
    unlink(file)
  }
})

testthat::test_that("download guards prevent replacement before network access", {
  target <- tempfile(fileext = ".gpkg"); writeLines("original", target)
  on.exit(unlink(target))
  testthat::expect_error(download_boundaries("https://example.org/file.gpkg", target), "File exists")
  testthat::expect_equal(readLines(target), "original")
  testthat::expect_error(download_boundaries("http://example.org/file.gpkg", tempfile()), "HTTPS")
})

testthat::test_that("boundary sources and council profiles are separate and complete", {
  catalogue <- readr::read_csv("config/boundary_sources.csv", show_col_types = FALSE)
  testthat::expect_setequal(catalogue$id,
    c("lad_2026", "lad_2025", "wards_2026", "wards_2025", "wards_2019", "msoa_2021",
      "msoa_2011", "lsoa_2021", "lsoa_2011", "oa_2021", "oa_2011"))
  testthat::expect_true(all(grepl("^https://services1[.]arcgis[.]com/", catalogue$service_url)))
  testthat::expect_equal(catalogue$boundary_id[catalogue$id == "oa_2021"], "lad_2026")
  testthat::expect_setequal(unique(catalogue$selection_method), c("attribute", "spatial"))
  profiles <- read_council_profiles()
  testthat::expect_true(mapper_config$default_council %in% profiles$council_id)
  filters <- readr::read_csv("config/council_source_filters.csv", show_col_types = FALSE)
  attribute_ids <- catalogue$id[catalogue$selection_method == "attribute"]
  testthat::expect_setequal(filters$source_id[filters$council_id == "thurrock"], attribute_ids)
  testthat::expect_match(council_map_dir("thurrock"), "data.input.map.thurrock")
  url <- arcgis_query_url(catalogue$service_url[[1]], 0,
                          list(where = filters$where[[1]], f = "json"))
  testthat::expect_match(url, "/0/query[?]")
  testthat::expect_match(url, "LAD26CD")
})
