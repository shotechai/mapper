# Reproducible visual QC outputs; run from the project root.
source("R/load.R")
folder <- council_map_dir("thurrock")
base <- load_map_layer(file.path(folder, "thurrock_wards_2019.gpkg"), "thurrock_wards_2019")
base$qc_value <- seq(0, 100, length.out = nrow(base))
base$qc_value[nrow(base)] <- NA_real_
make_overlay <- function(id, name, colour, shape = 16) {
  layer <- paste0("thurrock_", id)
  list(data = load_map_layer(file.path(folder, paste0(layer, ".gpkg")), layer),
    name = name, visible = TRUE, colour = colour, alpha = .9, size = 2.5,
    linewidth = .15, shape = shape, outline_only = TRUE, label = "")
}
overlays <- list(
  make_overlay("lower_thames_crossing_project_area", "LTC project area", "#BF5428"),
  make_overlay("major_parks_points", "Major parks", "#163B8F"),
  make_overlay("tourist_attractions_points", "Tourist / heritage sites", "#752879", 17))
overlays[[1]]$data <- restrict_overlay(overlays[[1]]$data, base, "Clip to base")
dir.create("output/qc", recursive = TRUE, showWarnings = FALSE)
s <- default_map_settings()
s$title <- "Thurrock: project area and visitor destinations"
s$subtitle <- "9 selected parks and 5 selected tourist / heritage locations"
s$high <- "#DCE9DC"
s$caption <- paste("Boundary: ONS. LTC: Planning Inspectorate via Planning Data (OGL). Parks: OS Open Greenspace (OS data).",
  "Attractions: OpenStreetMap contributors (ODbL), Historic England and English Heritage. Snapshot: 24 Oct 2026.",
  "Selected destinations; representative site points. LTC is a project extent, not a road centreline.", sep = "\n")
plot <- build_map(base, overlays, s) +
  ggplot2::theme(plot.title = ggplot2::element_text(colour = "#174E35"))
for (format in c("png", "pdf", "jpg")) export_map(plot,
  file.path("output/qc", paste0("thurrock-overlays.", format)), 11, 8, 150)
# Inspect all legend modes at ordinary report dimensions. QC values are
# deliberately synthetic and are never saved to the input GeoPackages.
for (method in c("Continuous", "Equal intervals", "Quantiles", "Fixed breaks")) {
  s$title <- paste("Legend QC:", method)
  s$subtitle <- "Synthetic values for display testing; not population statistics"
  s$caption <- "Boundary: ONS, 2019 wards. Synthetic QC values, including a missing value."
  s$variable <- "qc_value"; s$classification <- method
  s$legend <- "QC value"; s$units <- "%"; s$decimals <- 1
  s$breaks <- "0,20,40,60,80,100"; s$high <- "#007A3D"
  export_map(build_map(base, settings = s), file.path("output/qc",
    paste0("legend-", gsub(" ", "-", tolower(method)), ".png")), 10, 7, 120)
}
