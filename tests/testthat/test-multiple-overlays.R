withr::local_dir(testthat::test_path("..", ".."))

testthat::test_that("three successive additions retain independent overlays and reproduce together", {
  app_env <- new.env(parent = globalenv())
  suppressWarnings(sys.source("app.R", envir = app_env))
  extent <- sf::st_as_sfc(sf::st_bbox(c(xmin = 560000, ymin = 180000,
    xmax = 562000, ymax = 182000), crs = sf::st_crs(27700)))
  areas <- sf::st_sf(name = "Area", geometry = extent)
  parks <- sf::st_sf(name = "Park", geometry = sf::st_sfc(sf::st_point(c(560500, 180500)), crs = 27700))
  sites <- sf::st_sf(name = "Attraction", geometry = sf::st_sfc(sf::st_point(c(561500, 181500)), crs = 27700))
  path <- tempfile(fileext = ".gpkg")
  on.exit(unlink(path))
  sf::st_write(areas, path, layer = "areas", quiet = TRUE)
  sf::st_write(parks, path, layer = "parks", quiet = TRUE)
  sf::st_write(sites, path, layer = "sites", quiet = TRUE)
  pdf <- tempfile(fileext = ".pdf")
  grDevices::pdf(pdf)
  on.exit({grDevices::dev.off(); unlink(pdf)}, add = TRUE)
  shiny::testServer(app_env$server, {
    session$setInputs(folder = dirname(path), council_profile = "thurrock",
      base_file = path, base_layer = "areas", filter_column = "", format = "png",
      width = 4, height = 4, dpi = 100)
    session$setInputs(load_base = 1)
    session$setInputs(overlay_file = path, overlay_layer = "areas", overlay_mode = "Full layer",
      overlay_name = "", overlay_colour = "#BF5428", overlay_alpha = .8,
      overlay_size = 2, overlay_linewidth = .15, overlay_shape = "16",
      outline_only = TRUE, overlay_label = "")
    session$setInputs(add_overlay = 1)
    first <- state$overlays[[1]]
    session$setInputs(overlay_layer = "parks", overlay_colour = "#163B8F", add_overlay = 2)
    session$setInputs(overlay_layer = "sites", overlay_colour = "#752879", overlay_shape = "17", add_overlay = 3)
    testthat::expect_length(state$overlays, 3)
    testthat::expect_equal(state$overlays[[1]], first)
    testthat::expect_equal(vapply(state$overlays, function(x) x$name, character(1)), c("areas", "parks", "sites"))
    testthat::expect_equal(vapply(state$overlays, function(x) x$colour, character(1)), c("#BF5428", "#163B8F", "#752879"))
    testthat::expect_match(output$overlay_status, "3 added overlay layer")
    testthat::expect_match(output$overlay_status, "3 visible")
    plot <- current_plot()
    testthat::expect_length(plot$layers, 4) # Base and all three overlays.
    png <- tempfile(fileext = ".png")
    export_map(plot, png, 4, 4, 100)
    testthat::expect_gt(file.info(png)$size, 100)
    unlink(png)
    code <- sub("export_map\\(plot,.*$", "", reproduction_code())
    reproduced <- new.env(parent = globalenv())
    eval(parse(text = code), envir = reproduced)
    testthat::expect_length(reproduced$overlays, 3)
    for (i in 1:3) {
      # Source paths are emitted as load commands, not copied into style lists.
      keys <- names(reproduced$overlays[[i]])
      testthat::expect_equal(reproduced$overlays[[i]], state$overlays[[i]][keys])
    }
    # The same unchanged name must not block further additions.
    session$setInputs(overlay_name = "Same name", add_overlay = 4)
    session$setInputs(add_overlay = 5)
    session$setInputs(add_overlay = 6)
    testthat::expect_equal(vapply(state$overlays[4:6], function(x) x$name, character(1)),
      c("Same name", "Same name (2)", "Same name (3)"))
    session$setInputs(overlay_name = "Additional layer", add_overlay = 7)
    testthat::expect_equal(state$overlays[[7]]$name, "sites (2)")
    # A file/layer mismatch must leave all loaded overlays intact.
    session$setInputs(overlay_layer = "old_layer", add_overlay = 8)
    testthat::expect_length(state$overlays, 7)
    session$setInputs(selected_overlay = "2", toggle_overlay = 1)
    testthat::expect_false(state$overlays[[2]]$visible)
    testthat::expect_match(output$overlay_status, "6 visible")
    session$setInputs(selected_overlay = "3", remove_overlay = 1)
    testthat::expect_length(state$overlays, 6)
    testthat::expect_equal(state$overlays[[1]], first)
    testthat::expect_equal(state$overlays[[2]]$name, "parks")
  })
})
