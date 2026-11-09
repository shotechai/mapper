# List every spatial layer in every local GeoPackage, including multi-layer files.
# Return a tidy table so it is easy to inspect or filter with dplyr.
list_map_layers <- function(folder) {
  if (!dir.exists(folder)) stop("Input folder does not exist: ", folder)
  paths <- list.files(folder, pattern = "\\.gpkg$", full.names = TRUE,
                      recursive = TRUE, ignore.case = TRUE)
  rows <- lapply(paths, function(path) {
    info <- tryCatch(sf::st_layers(path), error = function(e) {
      stop("Cannot inspect ", basename(path), ": ", conditionMessage(e))
    })
    data.frame(file = normalizePath(path, winslash = "/"),
               layer = info$name, geometry = vapply(info$geomtype, paste, collapse = ", ", FUN.VALUE = character(1)),
               stringsAsFactors = FALSE)
  })
  if (!length(rows)) return(data.frame(file = character(), layer = character(),
                                       geometry = character()))
  dplyr::bind_rows(rows)
}

# Read one named layer. Missing CRS is an error: guessing can move features.
# Repair invalid polygons and transform all layers into one common map CRS.
load_map_layer <- function(file, layer, crs = mapper_config$map_crs) {
  x <- sf::st_read(file, layer = layer, quiet = TRUE)
  if (!nrow(x)) stop("The selected layer has no features.")
  if (is.na(sf::st_crs(x))) stop("Layer has no CRS. Assign the correct CRS in GIS first.")
  x <- sf::st_zm(x, drop = TRUE, what = "ZM")
  x <- sf::st_make_valid(x)
  x <- x[!sf::st_is_empty(x), , drop = FALSE]
  if (!nrow(x)) stop("The selected layer has only empty geometries.")
  types <- as.character(sf::st_geometry_type(x))
  if (!all(types %in% c("POLYGON", "MULTIPOLYGON", "POINT", "MULTIPOINT"))) {
    stop("Only polygon and point layers are supported in version 1.")
  }
  point_family <- types %in% c("POINT", "MULTIPOINT")
  if (any(point_family) && !all(point_family)) {
    stop("Separate points and polygons into different layers before loading.")
  }
  sf::st_transform(x, crs)
}

# Exact attribute selection works with a prefiltered file or a national dataset.
# For example, select a known local-authority code from an available LAD column.
select_map_area <- function(x, column = NULL, values = NULL) {
  if (is.null(column) || !nzchar(column)) return(x)
  if (!column %in% names(x)) stop("Selection column is not in this layer.")
  result <- x[as.character(x[[column]]) %in% as.character(values), , drop = FALSE]
  if (!nrow(result)) stop("No features match the selected value(s).")
  result
}

# Spatial selection is optional. Intersection keeps entire touching features;
# clipping cuts their geometry. Neither establishes official area membership.
restrict_overlay <- function(x, boundary, mode = "Full layer") {
  if (mode == "Full layer") return(x)
  if (!all(as.character(sf::st_geometry_type(boundary)) %in%
           c("POLYGON", "MULTIPOLYGON"))) stop("Selection boundary must be polygonal.")
  boundary <- sf::st_union(sf::st_transform(boundary, sf::st_crs(x)))
  if (mode == "Intersecting features") return(sf::st_filter(x, boundary))
  if (mode == "Clip to base") {
    dimension <- if (all(sf::st_dimension(x) == 0)) 0 else 2
    clipped <- suppressWarnings(sf::st_intersection(x, boundary))
    # Polygon features that only touch the boundary can become lines/points;
    # retain the original dimension so a polygon overlay stays polygonal.
    if (dimension == 2 && any(sf::st_geometry_type(clipped) == "GEOMETRYCOLLECTION")) {
      clipped <- suppressWarnings(sf::st_collection_extract(clipped, "POLYGON"))
    }
    return(clipped[sf::st_dimension(clipped) == dimension, , drop = FALSE])
  }
  stop("Unknown overlay selection mode.")
}

# Optional download of a direct GeoPackage or a ZIP containing GeoPackages.
# Download to a temporary location, validate it, and only then copy into input.
# Existing files are protected unless overwrite = TRUE is explicitly supplied.
download_boundaries <- function(url, destination, source_file = NULL,
                                overwrite = FALSE) {
  if (!grepl("^https://", url)) stop("Use a direct HTTPS download URL.")
  if (file.exists(destination) && !overwrite) stop("File exists; choose a new name or overwrite = TRUE.")
  if (!grepl("\\.gpkg$", destination, ignore.case = TRUE)) stop("Destination must end in .gpkg.")
  work <- tempfile("boundary-download-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  downloaded <- file.path(work, "download")
  utils::download.file(url, downloaded, mode = "wb", quiet = TRUE,
                       method = "libcurl")
  # Identify ZIPs by their header, not by a URL suffix that might contain a query.
  con <- file(downloaded, "rb")
  signature <- readBin(con, "raw", 4)
  close(con)
  if (length(signature) >= 2L && identical(signature[1:2], charToRaw("PK"))) {
    entries <- utils::unzip(downloaded, list = TRUE)$Name
    candidates <- entries[grepl("\\.gpkg$", entries, ignore.case = TRUE)]
    if (is.null(source_file)) {
      if (length(candidates) != 1L) stop("ZIP must have one GeoPackage, or specify source_file.")
      source_file <- candidates[[1]]
    }
    if (!source_file %in% candidates) stop("Requested GeoPackage is not in ZIP.")
    # Reject traversal paths before extracting an archive from an external source.
    if (grepl("(^/|^[A-Za-z]:|(^|[/\\\\])\\.\\.([/\\\\]|$))", source_file)) {
      stop("Unsafe archive path.")
    }
    utils::unzip(downloaded, files = source_file, exdir = work)
    downloaded <- file.path(work, source_file)
  }
  info <- sf::st_layers(downloaded)
  if (!length(info$name) || !identical(info$driver, "GPKG")) {
    stop("Download is not a readable GeoPackage. Use a direct GPKG or a ZIP containing one.")
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(downloaded, destination, overwrite = overwrite)) stop("Could not save download.")
  invisible(destination)
}

# Build an ArcGIS REST query without requiring another HTTP package.
arcgis_query_url <- function(service_url, layer_id = 0, parameters = list()) {
  if (!grepl("^https://", service_url)) stop("Use an HTTPS ArcGIS FeatureServer URL.")
  service_url <- sub("/+$", "", service_url)
  encoded <- vapply(names(parameters), function(name) {
    paste0(utils::URLencode(name, reserved = TRUE), "=",
           utils::URLencode(as.character(parameters[[name]]), reserved = TRUE))
  }, character(1))
  paste0(service_url, "/", as.integer(layer_id), "/query?", paste(encoded, collapse = "&"))
}

# Read a small JSON response via a temporary file so errors include the source URL.
read_remote_json <- function(url) {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  tryCatch(utils::download.file(url, path, mode = "wb", quiet = TRUE,
                                method = "libcurl"),
           error = function(e) stop("Could not download ONS service metadata: ",
                                    conditionMessage(e)))
  result <- jsonlite::read_json(path, simplifyVector = TRUE)
  if (!is.null(result$error)) {
    detail <- paste(c(result$error$message, unlist(result$error$details)), collapse = ": ")
    stop("ONS ArcGIS service error: ", detail)
  }
  result
}

# Return an ArcGIS envelope in WGS84 for a spatially restricted service query.
arcgis_envelope <- function(boundary) {
  boundary <- sf::st_transform(boundary, 4326)
  box <- sf::st_bbox(boundary)
  jsonlite::toJSON(list(xmin = unname(box[["xmin"]]),
                        ymin = unname(box[["ymin"]]),
                        xmax = unname(box[["xmax"]]),
                        ymax = unname(box[["ymax"]]),
                        spatialReference = list(wkid = 4326)), auto_unbox = TRUE)
}

# Download selected features from a public ArcGIS FeatureServer to a GeoPackage.
# Object IDs are fetched first so services with transfer limits are paged safely.
download_arcgis_boundaries <- function(service_url, destination, layer_name,
                                       where = "1=1", layer_id = 0,
                                       boundary = NULL, overwrite = FALSE,
                                       crs = mapper_config$map_crs) {
  if (file.exists(destination) && !overwrite) {
    stop("File exists; choose a new name or overwrite = TRUE.")
  }
  if (!grepl("\\.gpkg$", destination, ignore.case = TRUE)) {
    stop("Destination must end in .gpkg.")
  }
  if (!nzchar(layer_name)) stop("Provide a GeoPackage layer name.")

  metadata_url <- paste0(sub("/+$", "", service_url), "/", as.integer(layer_id), "?f=json")
  metadata <- read_remote_json(metadata_url)
  object_field <- metadata$objectIdField
  if (is.null(object_field) || !nzchar(object_field)) {
    object_fields <- metadata$fields$name[metadata$fields$type == "esriFieldTypeOID"]
    if (!length(object_fields)) stop("The ArcGIS layer has no object ID field.")
    object_field <- object_fields[[1]]
  }

  selection <- list(where = where, returnIdsOnly = "true", f = "json")
  if (!is.null(boundary)) {
    selection$geometry <- arcgis_envelope(boundary)
    selection$geometryType <- "esriGeometryEnvelope"
    selection$inSR <- "4326"
    selection$spatialRel <- "esriSpatialRelIntersects"
  }
  ids_result <- read_remote_json(arcgis_query_url(service_url, layer_id, selection))
  ids <- sort(unique(as.integer(ids_result$objectIds)))
  ids <- ids[!is.na(ids)]
  if (!length(ids)) stop("The ONS service query returned no features.")

  batch_size <- metadata$maxRecordCount
  if (is.null(batch_size) || !is.finite(batch_size) || batch_size < 1) batch_size <- 1000L
  # Keep GET query URLs below common proxy/server limits when object IDs are long.
  batch_size <- min(as.integer(batch_size), 100L)
  batches <- split(ids, ceiling(seq_along(ids) / batch_size))
  pieces <- lapply(batches, function(batch) {
    query <- list(where = paste0(object_field, " IN (", paste(batch, collapse = ","), ")"),
                  outFields = "*", returnGeometry = "true", outSR = as.character(crs),
                  f = "geojson")
    url <- arcgis_query_url(service_url, layer_id, query)
    path <- tempfile(fileext = ".geojson")
    on.exit(unlink(path), add = TRUE)
    tryCatch(utils::download.file(url, path, mode = "wb", quiet = TRUE,
                                  method = "libcurl"),
             error = function(e) stop("Could not download ONS boundary features: ",
                                      conditionMessage(e)))
    tryCatch(sf::st_read(path, quiet = TRUE),
             error = function(e) stop("The ONS service did not return readable GeoJSON: ",
                                      conditionMessage(e)))
  })
  result <- do.call(rbind, pieces)
  result <- sf::st_make_valid(sf::st_transform(result, crs))

  # The service envelope includes neighbouring polygons. Keep features whose
  # point-on-surface lies in the selected council; this avoids boundary-touching areas.
  if (!is.null(boundary)) {
    area <- sf::st_union(sf::st_transform(boundary, crs))
    inside <- lengths(sf::st_within(suppressWarnings(sf::st_point_on_surface(result)), area)) > 0
    result <- result[inside, , drop = FALSE]
    if (!nrow(result)) stop("No features remained inside the selected council boundary.")
  }

  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  sf::st_write(result, destination, layer = layer_name, quiet = TRUE,
               delete_dsn = overwrite)
  invisible(result)
}

# Read and validate reusable council profiles.
read_council_profiles <- function(path = "config/councils.csv") {
  profiles <- readr::read_csv(path, show_col_types = FALSE,
                              col_types = readr::cols(.default = readr::col_character()))
  required <- c("council_id", "council_name", "slug", "primary_colour", "light_colour")
  missing <- setdiff(required, names(profiles))
  if (length(missing)) stop("Council profiles are missing: ", paste(missing, collapse = ", "))
  if (anyDuplicated(profiles$council_id) || anyDuplicated(profiles$slug)) {
    stop("Council profile IDs and slugs must be unique.")
  }
  if (any(!grepl("^[a-z0-9-]+$", profiles$council_id)) ||
      any(!grepl("^[a-z0-9-]+$", profiles$slug))) {
    stop("Council IDs and slugs may contain lowercase letters, numbers and hyphens only.")
  }
  colours <- unlist(profiles[c("primary_colour", "light_colour")], use.names = FALSE)
  if (any(!grepl("^#[0-9A-Fa-f]{6}$", colours))) {
    stop("Council profile colours must be six-digit hex values.")
  }
  profiles
}

get_council_profile <- function(council_id = mapper_config$default_council,
                                path = "config/councils.csv") {
  profiles <- read_council_profiles(path)
  profile <- profiles[profiles$council_id == council_id, , drop = FALSE]
  if (nrow(profile) != 1) stop("Unknown council profile: ", council_id)
  profile
}

council_map_dir <- function(council_id = mapper_config$default_council,
                            profiles_path = "config/councils.csv") {
  profile <- get_council_profile(council_id, profiles_path)
  file.path(mapper_config$map_dir, profile$slug)
}

council_indicator_dir <- function(council_id = mapper_config$default_council,
                                  profiles_path = "config/councils.csv") {
  profile <- get_council_profile(council_id, profiles_path)
  file.path(mapper_config$indicator_dir, profile$slug)
}

# Download each configured edition for one council. Attribute filters live in a
# separate council/source table; spatial rows reuse an earlier LAD boundary row.
download_boundary_catalogue <- function(council_id = mapper_config$default_council,
                                        catalogue_path = "config/boundary_sources.csv",
                                        profiles_path = "config/councils.csv",
                                        filters_path = "config/council_source_filters.csv",
                                        input_dir = NULL, overwrite = FALSE) {
  profile <- get_council_profile(council_id, profiles_path)
  if (is.null(input_dir)) input_dir <- file.path(mapper_config$map_dir, profile$slug)
  catalogue <- readr::read_csv(catalogue_path, show_col_types = FALSE,
                               col_types = readr::cols(.default = readr::col_character()))
  filters <- readr::read_csv(filters_path, show_col_types = FALSE,
                             col_types = readr::cols(.default = readr::col_character()))
  required <- c("id", "geography", "label", "edition", "service_url", "layer_id",
                "selection_method", "boundary_id", "source_note")
  missing <- setdiff(required, names(catalogue))
  if (length(missing)) stop("Boundary catalogue is missing: ", paste(missing, collapse = ", "))
  if (anyDuplicated(catalogue$id)) stop("Boundary catalogue IDs must be unique.")
  if (anyNA(catalogue$service_url) || any(!nzchar(catalogue$service_url))) {
    stop("Every boundary catalogue row needs an official service URL.")
  }

  downloaded <- list()
  manifest <- vector("list", nrow(catalogue))
  for (i in seq_len(nrow(catalogue))) {
    row <- catalogue[i, ]
    layer_name <- paste(profile$slug, row$id, sep = "_")
    destination <- file.path(input_dir, paste0(layer_name, ".gpkg"))
    boundary <- NULL
    boundary_id <- if (is.na(row$boundary_id)) "" else row$boundary_id
    method <- row$selection_method
    if (!method %in% c("attribute", "spatial")) {
      stop("Unknown selection method for ", row$id, ": ", method)
    }
    where <- "1=1"
    if (method == "attribute") {
      selected_filter <- filters[filters$council_id == council_id &
                                   filters$source_id == row$id, , drop = FALSE]
      if (nrow(selected_filter) != 1 || is.na(selected_filter$where) ||
          !nzchar(selected_filter$where)) {
        stop("Add exactly one non-empty filter for council ", council_id,
             " and source ", row$id, " in ", filters_path, ".")
      }
      where <- selected_filter$where
    }
    if (method == "spatial") {
      if (!boundary_id %in% names(downloaded)) {
        stop("Catalogue row ", row$id, " refers to boundary_id ", boundary_id,
             " before that boundary has been loaded.")
      }
      boundary <- downloaded[[boundary_id]]
    }

    if (file.exists(destination) && !overwrite) {
      message("Keeping existing ", destination)
      downloaded[[row$id]] <- load_map_layer(destination, layer_name)
      status <- "existing"
    } else {
      message("Downloading ", profile$council_name, " ", row$label,
              " (", row$edition, ")")
      downloaded[[row$id]] <- download_arcgis_boundaries(
        service_url = row$service_url,
        destination = destination,
        layer_name = layer_name, where = where,
        layer_id = as.integer(row$layer_id), boundary = boundary,
        overwrite = overwrite)
      status <- "downloaded"
    }
    manifest[[i]] <- data.frame(council_id = council_id,
                                council_name = profile$council_name,
                                id = row$id, geography = row$geography,
                                label = paste(profile$council_name, row$label),
                                edition = row$edition,
                                file = gsub("\\\\", "/", destination),
                                layer = layer_name,
                                features = nrow(downloaded[[row$id]]), status = status,
                                source = row$service_url,
                                source_note = row$source_note,
                                stringsAsFactors = FALSE)
  }
  dplyr::bind_rows(manifest)
}

download_all_councils <- function(overwrite = FALSE) {
  profiles <- read_council_profiles()
  result <- lapply(profiles$council_id, function(id) {
    manifest <- download_boundary_catalogue(id, overwrite = overwrite)
    output <- council_map_dir(id)
    readr::write_csv(manifest, file.path(output, "boundary_manifest.csv"))
    manifest
  })
  dplyr::bind_rows(result)
}
