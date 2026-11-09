# Run once from the project root. Install only missing packages.
# On Windows/macOS, use current R and CRAN binaries where available.
packages <- c("sf", "dplyr", "readr", "ggplot2", "shiny", "bslib", "jsonlite", "testthat")
missing <- packages[!vapply(packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Dependencies are installed. Start with shiny::runApp('.').")
