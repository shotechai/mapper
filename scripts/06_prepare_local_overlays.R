# Run from the project root. Raw public downloads are retained for reproducibility.
# Set refresh <- TRUE to fetch a new snapshot before rebuilding the GeoPackages.
source("R/load.R")
refresh <- FALSE
sources <- c(
  ltc_source.geojson = "https://www.planning.data.gov.uk/entity/11100000133.geojson",
  coalhouse_source.geojson = "https://www.planning.data.gov.uk/entity/7500716.geojson",
  greenspace_source.geojson = paste0("https://services.arcgis.com/qHLhLQrcvEnxjtPr/arcgis/rest/services/OS_Open_Greenspace/FeatureServer/1/query?f=geojson&where=1%3D1&geometry=0.19%2C51.44%2C0.56%2C51.60&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&outSR=4326&resultRecordCount=2000"),
  tourism_source.geojson = paste0("https://services-eu1.arcgis.com/zci5bUiJ8olAal7N/arcgis/rest/services/OSM_EU_Tourism/FeatureServer/0/query?f=geojson&where=1%3D1&geometry=0.19%2C51.44%2C0.56%2C51.60&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&outSR=4326")
)
for (file in names(sources)) {
  path <- file.path("data/input", file)
  if (refresh || !file.exists(path)) utils::download.file(sources[[file]], path, mode = "wb")
  raw <- jsonlite::read_json(path)
  if (!is.null(raw$error) || isTRUE(raw$exceededTransferLimit) ||
      isTRUE(raw$properties$exceededTransferLimit)) stop("Incomplete source download: ", file)
}
read_source <- function(file) {
  path <- file.path("data/input", file)
  raw <- jsonlite::read_json(path)
  # Older GDAL builds require the GeoJSON type near the start of a large file.
  if (identical(raw$type, "Feature")) {
    path <- tempfile(fileext = ".geojson")
    on.exit(unlink(path))
    jsonlite::write_json(list(type = "FeatureCollection", features = list(raw)),
      path, auto_unbox = TRUE)
  }
  sf::st_make_valid(sf::st_transform(sf::st_read(path, quiet = TRUE), 27700))
}
folder <- council_map_dir("thurrock")
boundary <- load_map_layer(file.path(folder, "thurrock_lad_2026.gpkg"), "thurrock_lad_2026")
ltc <- read_source("ltc_source.geojson")
ltc$source_url <- unname(sources[["ltc_source.geojson"]])
ltc$location_method <- "Published project area; not a road centreline or construction drawing"
ltc$licence <- "Open Government Licence v3.0"

# OS Open Greenspace supplies polygons. Points lie inside the Thurrock portion
# of each selected park; they indicate the site, not an entrance or car park.
greenspace <- read_source("greenspace_source.geojson")
major <- c("Langdon Hills Country Park", "Grays Beach Riverside Park", "Grays Park",
  "Chafford Gorges Nature Park", "Mardyke Country Park", "Belhus Woods Country Park",
  "Little Belhus Country Park", "Dilkes Park", "Thomas Bata Memorial Park")
greenspace$name <- trimws(greenspace$distName1)
parks <- greenspace[greenspace$name %in% major, c("id", "name")]
parks <- suppressWarnings(sf::st_intersection(parks, sf::st_union(boundary)))
parks <- parks[as.numeric(sf::st_area(parks)) > 0, ]
parks <- suppressWarnings(sf::st_point_on_surface(parks))
parks$source_url <- "https://services.arcgis.com/qHLhLQrcvEnxjtPr/arcgis/rest/services/OS_Open_Greenspace/FeatureServer/1"
parks$location_method <- "Representative point inside OS park polygon clipped to Thurrock; not an entrance"
parks$licence <- "Contains OS data, Crown copyright and database right 2026; OGL v3.0"

# A selected visitor/heritage layer is used because a complete council attraction
# point download was unavailable. Keep only named destinations, excluding hotels,
# information boards, artworks, picnic sites and unnamed features.
tourism <- read_source("tourism_source.geojson")
tourism <- sf::st_filter(tourism, boundary)
tourism <- tourism[!is.na(tourism$name) & tourism$tourism %in%
  c("attraction", "museum", "gallery", "viewpoint", "theme_park"), ]
tourism <- tourism[nzchar(trimws(tourism$name)), ]
tourism <- tourism[, c("name", "tourism")]
names(tourism)[names(tourism) == "tourism"] <- "category"
tourism$source_url <- "https://services-eu1.arcgis.com/zci5bUiJ8olAal7N/arcgis/rest/services/OSM_EU_Tourism/FeatureServer/0"
tourism$location_method <- "Published OpenStreetMap point via Esri public tourism service"
tourism$licence <- "Copyright OpenStreetMap contributors; ODbL 1.0"

coalhouse <- read_source("coalhouse_source.geojson")
coalhouse <- suppressWarnings(sf::st_point_on_surface(coalhouse))
coalhouse <- sf::st_sf(name = "Coalhouse Fort", category = "Heritage fort",
  source_url = "https://www.planning.data.gov.uk/entity/7500716",
  location_method = "Representative point inside published Historic England heritage area; not an entrance",
  licence = "Open Government Licence v3.0", geometry = sf::st_geometry(coalhouse))
tilbury <- sf::st_as_sf(data.frame(name = "Tilbury Fort", category = "Heritage fort",
  source_url = "https://www.english-heritage.org.uk/visit/places/tilbury-fort/directions/",
  location_method = "Published English Heritage visitor sat-nav coordinate",
  licence = "Coordinate transcribed from English Heritage directions; source attribution retained",
  longitude = .374501, latitude = 51.451978), coords = c("longitude", "latitude"), crs = 4326)
tourism <- rbind(tourism, coalhouse, sf::st_transform(tilbury, 27700))
tourism <- tourism[!duplicated(tourism$name), ]

datasets <- list(lower_thames_crossing_project_area = ltc,
  major_parks_points = parks, tourist_attractions_points = tourism)
manifest <- list()
for (id in names(datasets)) {
  x <- datasets[[id]]
  x$snapshot_date <- "2026-10-24"
  stopifnot(nrow(x) > 0, all(sf::st_is_valid(x)), !any(sf::st_is_empty(x)))
  if (id != "lower_thames_crossing_project_area") {
    stopifnot(all(sf::st_geometry_type(x) == "POINT"),
      all(lengths(sf::st_intersects(x, boundary)) > 0))
  }
  layer <- paste0("thurrock_", id)
  file <- file.path(folder, paste0(layer, ".gpkg"))
  sf::st_write(x, file, layer = layer, quiet = TRUE, delete_dsn = TRUE)
  check <- load_map_layer(file, layer)
  stopifnot(nrow(check) == nrow(x), sf::st_crs(check)$epsg == 27700)
  manifest[[id]] <- data.frame(file = basename(file), layer = layer,
    features = nrow(x), geometry = paste(unique(sf::st_geometry_type(x)), collapse = ", "),
    snapshot_date = "2026-10-24", source_note = "See docs/LOCAL_OVERLAYS.md and feature source_url / location_method / licence fields")
}
readr::write_csv(dplyr::bind_rows(manifest), file.path(folder, "overlay_manifest.csv"))
print(dplyr::bind_rows(manifest))
