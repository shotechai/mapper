# The app is optional: use these same functions in a normal R script.
# First run scripts/02_create_demo.R once to create the fictional input files.
source("R/load.R")

# 1. Inspect available files and layers; load the chosen base geography.
print(list_map_layers("data/input"))
areas <- load_map_layer("data/input/demo.gpkg", "demo_areas")

# 2. Join a CSV by its area code and inspect the match diagnostics.
indicators <- read_indicator_data("data/input/demo_indicators.csv")
joined <- join_map_data(areas, indicators, "code", "code")
print(joined$summary)

# 3. Calculate a percentage from counts, without averaging existing percentages.
joined$map$percentage <- calculate_percentage(joined$map$data_numerator,
                                              joined$map$data_denominator)

# 4. Add a point overlay. Polygon overlays use the same list structure.
points <- load_map_layer("data/input/demo.gpkg", "demo_points")
overlay <- list(data = points, name = "Example sites", visible = TRUE,
                colour = "#232323", size = 3, alpha = 1, shape = 16,
                outline_only = FALSE, label = "site")

# 5. Choose presentation settings, then preview/export the same plot object.
settings <- default_map_settings()
settings$title <- "Fictional demonstration — not real boundaries"
settings$variable <- "percentage"
settings$legend <- "Percentage (%)"
settings$units <- "%"
settings$caption <- "Source: synthetic demonstration data."
plot <- build_map(joined$map, list(overlay), settings)
print(plot)
dir.create("outputs", showWarnings = FALSE)
export_map(plot, "outputs/demo_map.png")
export_map(plot, "outputs/demo_map.pdf")
