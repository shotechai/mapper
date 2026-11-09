# Download current and previous boundary editions for one configured council.
# Change council_id after adding a profile and source filters in config/.
source("R/load.R")
council_id <- mapper_config$default_council
manifest <- download_boundary_catalogue(council_id, overwrite = FALSE)
output_dir <- council_map_dir(council_id)
readr::write_csv(manifest, file.path(output_dir, "boundary_manifest.csv"))
print(manifest[, c("label", "edition", "features", "status")])
message("Boundary set is ready in ", output_dir,
        ". The app can see the GeoPackages after Refresh files.")
