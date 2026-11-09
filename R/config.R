# Central toolkit settings. Council-specific names and colours live in
# config/councils.csv so the mapper can be reused without changing R code.
mapper_config <- list(
  app_name = "Mapper",
  default_council = "thurrock",
  input_dir = "data/input",
  map_dir = "data/input/map",
  indicator_dir = "data/input/indicator",
  green = "#007A3D",
  light_green = "#EFF7EE",
  missing_colour = "#D9D9D9",
  map_crs = 27700, # British National Grid; appropriate for the England workflow.
  colour_note = "Defaults come from the selected council profile and can be changed here."
)
