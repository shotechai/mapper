withr::local_dir(testthat::test_path("..", ".."))

testthat::test_that("band labels describe boundaries without interval punctuation", {
  for (method in c("Equal intervals", "Quantiles", "Fixed breaks")) {
    bands <- classify_values(c(0, 10, 20, NA), method, 2, "0,10,20", 1, "%")
    testthat::expect_equal(levels(bands), c("0.0% to 10.0%", "> 10.0% to 20.0%"))
    testthat::expect_equal(as.integer(bands), c(1L, 1L, 2L, NA_integer_))
  }
  testthat::expect_equal(levels(classify_values(c(2, 2, NA), "Quantiles", decimals = 2)), "2.00")
  testthat::expect_length(unique(levels(classify_values(c(0, .002), "Equal intervals", 2))), 2)
})

testthat::test_that("polygon widths are independent of point sizes", {
  b <- sf::st_sf(name = "Area", geometry = sf::st_as_sfc(sf::st_bbox(
    c(xmin = 560000, ymin = 180000, xmax = 562000, ymax = 182000), crs = sf::st_crs(27700))))
  item <- list(data = b, name = "Boundary", visible = TRUE, colour = "#333333",
    size = 8, linewidth = .1, alpha = 1, shape = 16, outline_only = TRUE, label = "")
  plot <- build_map(b, list(item))
  testthat::expect_equal(plot$layers[[2]]$aes_params$linewidth, .1)
  item$linewidth <- NULL
  testthat::expect_equal(build_map(b, list(item))$layers[[2]]$aes_params$linewidth, .25)
  item$data <- sf::st_point_on_surface(sf::st_geometry(b)) |> sf::st_sf()
  testthat::expect_equal(build_map(b, list(item))$layers[[2]]$aes_params$size, 8)
})

testthat::test_that("new map catalogue contains valid local overlays", {
  folder <- council_map_dir("thurrock")
  testthat::skip_if_not(file.exists(file.path(folder, "overlay_manifest.csv")), "Local overlay snapshot is optional in source-only checkouts")
  catalogue <- list_map_layers(folder)
  manifest <- readr::read_csv(file.path(folder, "overlay_manifest.csv"), show_col_types = FALSE)
  testthat::expect_equal(manifest$features, c(1, 9, 5))
  testthat::expect_true(all(manifest$layer %in% catalogue$layer))
  boundary <- load_map_layer(file.path(folder, "thurrock_lad_2026.gpkg"), "thurrock_lad_2026")
  for (i in seq_len(nrow(manifest))) {
    x <- load_map_layer(file.path(folder, manifest$file[i]), manifest$layer[i])
    testthat::expect_equal(nrow(x), manifest$features[i])
    testthat::expect_true(all(sf::st_is_valid(x)))
    testthat::expect_equal(sf::st_crs(x)$epsg, 27700)
    if (i > 1) {
      testthat::expect_true(all(sf::st_geometry_type(x) == "POINT"))
      testthat::expect_true(all(lengths(sf::st_intersects(x, boundary)) > 0))
    }
  }
})

testthat::test_that("base boundary settings apply to every classification and support hidden strokes", {
  extent <- sf::st_as_sfc(sf::st_bbox(c(xmin = 560000, ymin = 180000,
    xmax = 562000, ymax = 182000), crs = sf::st_crs(27700)))
  base <- sf::st_sf(value = c(0, 10, 20, NA), geometry = sf::st_make_grid(extent, n = c(2, 2)))
  for (method in c("Plain", "Continuous", "Equal intervals", "Quantiles", "Fixed breaks")) {
    s <- default_map_settings()
    s$base_linewidth <- .65; s$base_boundary_colour <- "#123456"
    if (method != "Plain") {
      s$classification <- method; s$variable <- "value"; s$breaks <- "0,10,20"
    }
    plot <- build_map(base, settings = s)
    testthat::expect_equal(plot$layers[[1]]$aes_params$linewidth, .65)
    testthat::expect_equal(plot$layers[[1]]$aes_params$colour, "#123456")
    s$base_linewidth <- 0
    testthat::expect_true(is.na(build_map(base, settings = s)$layers[[1]]$aes_params$colour))
  }
  testthat::expect_error(build_map(base, settings = list(base_linewidth = -1)), "thickness")
  testthat::expect_error(build_map(base, settings = list(base_linewidth = 4)), "thickness")
  testthat::expect_error(build_map(base, settings = list(base_boundary_colour = "invalid")), "hex")
  # Older appearance settings continue to receive the default boundary style.
  old <- default_map_settings()[setdiff(names(default_map_settings()), c("base_linewidth", "base_boundary_colour"))]
  testthat::expect_equal(build_map(base, settings = old)$layers[[1]]$aes_params$colour, "#FFFFFF")
})
