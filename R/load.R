# Source this file from the project root to load all reusable functions.
# No packages are attached globally; package::function makes dependencies explicit.
required_packages <- c("sf", "dplyr", "readr", "ggplot2", "shiny", "bslib", "jsonlite")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
                                              quietly = TRUE, FUN.VALUE = logical(1))]
if (length(missing_packages)) {
  stop("Install required packages first: ", paste(missing_packages, collapse = ", "),
       ". Run source('scripts/01_install.R').")
}
for (script in c("config.R", "io.R", "data.R", "map.R")) {
  source(file.path("R", script), local = FALSE)
}
