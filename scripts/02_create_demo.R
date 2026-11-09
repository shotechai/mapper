# This optional demo creates fictional squares and points, not real council areas.
source("R/load.R")
dir.create(mapper_config$input_dir, recursive = TRUE, showWarnings = FALSE)
path <- file.path(mapper_config$input_dir, "demo.gpkg")
if (file.exists(path)) stop("demo.gpkg already exists. Remove it manually to rebuild.")

# Build four adjacent fictional areas in British National Grid coordinates.
box <- sf::st_as_sfc(sf::st_bbox(c(xmin = 560000, ymin = 180000,
                                  xmax = 568000, ymax = 188000), crs = sf::st_crs(27700)))
areas <- sf::st_sf(code = sprintf("DEMO%02d", 1:4),
                   area = paste("Example area", 1:4),
                   geometry = sf::st_make_grid(box, n = c(2, 2)))
points <- sf::st_sf(site = c("Example site A", "Example site B"),
                    geometry = sf::st_sfc(sf::st_point(c(562000, 182000)),
                                           sf::st_point(c(566000, 186000)), crs = 27700))
zone <- sf::st_sf(zone = "Fictional overlay", geometry = sf::st_buffer(points[1, ], 1800)$geometry)
sf::st_write(areas, path, layer = "demo_areas", quiet = TRUE)
sf::st_write(points, path, layer = "demo_points", quiet = TRUE)
sf::st_write(zone, path, layer = "demo_zone", quiet = TRUE)

# Provide a matching table with numerator/denominator and a deliberately missing value.
readr::write_csv(data.frame(code = areas$code, count = c(12, 25, NA, 40),
                            numerator = c(12, 25, NA, 40), denominator = c(100, 80, 90, 120)),
                 file.path(mapper_config$input_dir, "demo_indicators.csv"))
message("Fictional demo files created in data/input. Refresh the app's file list.")
