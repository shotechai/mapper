# Defaults are shared by scripts and the app. This is also the saved settings format.
default_map_settings <- function() {
  list(title = "Area map", title_align = "middle", subtitle = "", caption = "",
       variable = "", variable_type = "Numeric", value_scale = "raw",
       category_colours = list(),
       legend = "Value", units = "", decimals = 1,
       classification = "Continuous", classes = 5, breaks = "",
       low = mapper_config$light_green, high = mapper_config$green,
       missing = mapper_config$missing_colour, label = "", labels = FALSE,
       label_size = 3, label_colour = "#000000", label_font = "sans",
       legend_colour = "#000000", legend_font = "sans",
       legend_position = "right", base_alpha = 1,
       base_linewidth = 0.25, base_boundary_colour = "#FFFFFF", canvas_boundary = FALSE,
       zoom = 1, centre_x = 0.5, centre_y = 0.5)
}

# Start with a readable qualitative palette, then replace any categories for
# which the user supplied a six-digit hex colour.
category_palette <- function(categories, overrides = list()) {
  categories <- as.character(categories)
  colours <- stats::setNames(
    grDevices::hcl.colors(length(categories), palette = "Dynamic"), categories)
  if (!length(overrides)) return(colours)
  custom <- unlist(overrides, use.names = TRUE)
  if (is.null(names(custom)) || any(!nzchar(names(custom))) ||
      any(!grepl("^#[0-9A-Fa-f]{6}$", custom))) {
    stop("Category colours must be named six-digit hex codes.")
  }
  matched <- intersect(categories, names(custom))
  colours[matched] <- custom[matched]
  colours
}

# Produce factor bands for discrete maps. Fixed breaks must cover all values;
# quantiles may have fewer bands when there are tied values.
classify_values <- function(values, method, classes = 5, breaks = "", decimals = 1, units = "") {
  finite <- values[is.finite(values)]
  if (!length(finite)) stop("The indicator has no non-missing numeric values.")
  if (method == "Fixed breaks") {
    edges <- suppressWarnings(as.numeric(trimws(strsplit(breaks, ",", fixed = TRUE)[[1]])))
    if (length(edges) < 2 || anyNA(edges) || any(diff(edges) <= 0)) {
      stop("Enter increasing comma-separated breaks, for example 0,20,40,60,80,100.")
    }
  } else if (method == "Quantiles") {
    edges <- unique(as.numeric(stats::quantile(finite, probs = seq(0, 1, length.out = classes + 1))))
  } else {
    edges <- unique(seq(min(finite), max(finite), length.out = classes + 1))
  }
  format_edge <- function(x, digits = decimals) paste0(formatC(x, format = "f", digits = digits), units)
  if (length(edges) < 2) return(factor(ifelse(is.na(values), NA, format_edge(finite[1]))))
  if (min(finite) < min(edges) || max(finite) > max(edges)) stop("Breaks must cover all indicator values.")
  # Raise display precision when rounding would make distinct breaks look equal.
  digits <- decimals
  while (anyDuplicated(format_edge(edges, digits)) && digits < 10) digits <- digits + 1
  display <- format_edge(edges, digits)
  labels <- paste0(c("", rep("> ", length(edges) - 2)), head(display, -1), " to ", tail(display, -1))
  cut(values, breaks = edges, include.lowest = TRUE, labels = labels)
}

# Each overlay gets its own five-band numeric ramp and labelled legend entries.
# RGB fills are supplied directly so the base indicator retains its own fill scale.
overlay_value_colours <- function(item, missing = "#D9D9D9", decimals = 1, units = "") {
  values <- numeric_indicator(item$data[[item$variable]])
  finite <- values[is.finite(values)]
  if (!length(finite)) stop("The overlay indicator has no numeric values.")
  bands <- classify_values(values, "Equal intervals", classes = 5, decimals = decimals, units = units)
  palette <- grDevices::colorRampPalette(c(item$low, item$high))(nlevels(bands))
  keys <- paste(item$name, item$variable, levels(bands), sep = " · ")
  colours <- stats::setNames(palette, keys)
  labels <- keys[as.integer(bands)]
  if (anyNA(labels)) {
    missing_key <- paste(item$name, "Missing data", sep = " · ")
    labels[is.na(labels)] <- missing_key
    colours <- c(colours, stats::setNames(missing, missing_key))
  }
  list(labels = labels, colours = colours, fill = unname(colours[labels]))
}

# Make one ggplot object for BOTH preview and export so symbology stays consistent.
# Layer order follows the overlays list: its last item is drawn on top.
build_map <- function(base, overlays = list(), settings = default_map_settings()) {
  s <- utils::modifyList(default_map_settings(), settings)
  if (!s$variable_type %in% c("Numeric", "Categorical")) {
    stop("Choose numeric or categorical colouring.")
  }
  if (!s$value_scale %in% c("raw", "fraction_percent")) {
    stop("Choose values as entered or fractional percentages.")
  }
  if (!s$classification %in% c("Continuous", "Equal intervals", "Quantiles", "Fixed breaks")) {
    stop("Choose a supported classification method.")
  }
  if (!s$title_align %in% c("left", "middle", "right")) {
    stop("Choose left, middle or right title alignment.")
  }
  if (length(s$classes) != 1 || !is.finite(s$classes) || s$classes < 2 ||
      s$classes > 9 || s$classes != floor(s$classes)) stop("Choose 2 to 9 whole-number bands.")
  if (!is.finite(s$decimals) || s$decimals < 0 || s$decimals > 5 ||
      s$decimals != floor(s$decimals)) stop("Choose 0 to 5 whole-number decimal places.")
  if (!is.finite(s$base_alpha) || s$base_alpha < 0 || s$base_alpha > 1) stop("Opacity must be between 0 and 1.")
  if (length(s$base_linewidth) != 1 || !is.finite(s$base_linewidth) ||
      s$base_linewidth < 0 || s$base_linewidth > 3) {
    stop("Base polygon boundary thickness must be between 0 and 3 mm.")
  }
  for (colour in c(s$low, s$high, s$missing, s$label_colour, s$legend_colour, s$base_boundary_colour)) {
    if (!grepl("^#[0-9A-Fa-f]{6}$", colour)) stop("Use six-digit hex colours.")
  }
  if (any(!is.finite(c(s$zoom, s$centre_x, s$centre_y))) || s$zoom < 0.5 || s$zoom > 16 ||
      any(c(s$centre_x, s$centre_y) < 0) || any(c(s$centre_x, s$centre_y) > 1)) {
    stop("Use zoom 0.5 to 16 and centre coordinates between 0 and 1.")
  }
  polygon <- all(as.character(sf::st_geometry_type(base)) %in% c("POLYGON", "MULTIPOLYGON"))
  if (!polygon) stop("The base map must be a polygon layer; add points as overlays.")
  # NA removes strokes at zero width, avoiding hairlines in PDF output.
  boundary_colour <- if (s$base_linewidth == 0) NA else s$base_boundary_colour
  p <- ggplot2::ggplot()
  if (nzchar(s$variable)) {
    if (!s$variable %in% names(base)) stop("Selected indicator is no longer available.")
    if (s$variable_type == "Categorical") {
      category <- trimws(as.character(base[[s$variable]]))
      category[is.na(category) | !nzchar(category)] <- NA_character_
      levels <- sort(unique(category[!is.na(category)]))
      if (!length(levels)) stop("The category column has no non-missing values.")
      base$.map_category <- factor(category, levels = levels)
      colours <- category_palette(levels, s$category_colours)
      p <- p + ggplot2::geom_sf(data = base, ggplot2::aes(fill = .map_category),
                                colour = boundary_colour, linewidth = s$base_linewidth, alpha = s$base_alpha) +
        ggplot2::scale_fill_manual(values = colours,
          na.value = s$missing, drop = FALSE, name = s$legend,
          labels = function(x) ifelse(is.na(x), "Missing data", x))
    } else {
      base$.map_value <- scale_indicator_values(base[[s$variable]], s$value_scale)
      if (!any(is.finite(base$.map_value))) stop("The indicator has no numeric values.")
      display_units <- if (s$value_scale == "fraction_percent" && !nzchar(s$units)) "%" else s$units
      if (s$classification == "Continuous") {
        p <- p + ggplot2::geom_sf(data = base, ggplot2::aes(fill = .map_value),
                                  colour = boundary_colour, linewidth = s$base_linewidth, alpha = s$base_alpha) +
          ggplot2::scale_fill_gradient(low = s$low, high = s$high, na.value = s$missing,
            name = s$legend, labels = function(x) paste0(formatC(x, format = "f", digits = s$decimals), display_units))
      } else {
        base$.map_band <- classify_values(base$.map_value, s$classification, s$classes, s$breaks, s$decimals, display_units)
        colours <- grDevices::colorRampPalette(c(s$low, s$high))(nlevels(base$.map_band))
        p <- p + ggplot2::geom_sf(data = base, ggplot2::aes(fill = .map_band),
                                  colour = boundary_colour, linewidth = s$base_linewidth, alpha = s$base_alpha) +
          ggplot2::scale_fill_manual(values = stats::setNames(colours, levels(base$.map_band)),
                                     na.value = s$missing, drop = FALSE, name = s$legend)
      }
    }
  } else {
    p <- p + ggplot2::geom_sf(data = base, fill = s$high, colour = boundary_colour,
                             linewidth = s$base_linewidth, alpha = s$base_alpha)
  }
  # Overlay colours are constants, keeping the thematic fill legend unambiguous.
  visible_overlays <- Filter(function(item) isTRUE(item$visible), overlays)
  if (length(visible_overlays)) {
    overlay_names <- vapply(visible_overlays, function(item) item$name, character(1))
    if (anyDuplicated(overlay_names)) stop("Overlay names must be unique.")
  }
  legend_colours <- character()
  for (item in overlays) {
    if (!isTRUE(item$visible)) next
    x <- sf::st_transform(item$data, sf::st_crs(base))
    thematic <- !is.null(item$variable) && nzchar(item$variable)
    if (thematic) {
      style <- overlay_value_colours(item, s$missing, s$decimals)
      x$.map_overlay <- style$labels
      legend_colours <- c(legend_colours, style$colours)
    } else {
      x$.map_overlay <- item$name
      legend_colours <- c(legend_colours, stats::setNames(item$colour, item$name))
    }
    if (all(as.character(sf::st_geometry_type(x)) %in% c("POINT", "MULTIPOINT"))) {
      p <- p + ggplot2::geom_sf(data = x, ggplot2::aes(colour = .map_overlay), size = item$size,
                               alpha = item$alpha, shape = item$shape)
    } else {
      p <- p + ggplot2::geom_sf(data = x, ggplot2::aes(colour = .map_overlay),
                               fill = if (thematic) style$fill else if (item$outline_only) NA else item$colour,
                               alpha = item$alpha, linewidth = if (is.null(item$linewidth)) 0.25 else item$linewidth)
    }
    if (nzchar(item$label)) {
      x$.map_overlay_label <- as.character(x[[item$label]])
      p <- p + ggplot2::geom_sf_text(data = x, ggplot2::aes(label = .map_overlay_label),
                                     size = s$label_size, colour = s$label_colour,
                                     family = s$label_font, check_overlap = TRUE)
    }
  }
  if (length(visible_overlays)) {
    p <- p + ggplot2::scale_colour_manual(values = legend_colours, breaks = names(legend_colours), name = "Layers")
  }
  # Labels are placed last so they remain above polygon overlays.
  if (isTRUE(s$labels) && nzchar(s$label)) {
    if (!s$label %in% names(base)) stop("Selected label column is unavailable.")
    label <- base[[s$label]]
    if (is.numeric(label)) label <- formatC(label, format = "f", digits = s$decimals)
    base$.map_label <- ifelse(is.na(label), "", as.character(label))
    p <- p + ggplot2::geom_sf_text(data = base, ggplot2::aes(label = .map_label),
                                   size = s$label_size, colour = s$label_colour,
                                     family = s$label_font, check_overlap = TRUE)
  }
  # Keep the viewport centred on the base, even if an external overlay is national.
  extent <- sf::st_bbox(base)
  span_x <- unname(extent["xmax"] - extent["xmin"])
  span_y <- unname(extent["ymax"] - extent["ymin"])
  centre_x <- unname(extent["xmin"]) + s$centre_x * span_x
  centre_y <- unname(extent["ymin"]) + s$centre_y * span_y
  p + ggplot2::coord_sf(crs = sf::st_crs(base),
                        xlim = centre_x + c(-0.5, 0.5) * span_x / s$zoom,
                        ylim = centre_y + c(-0.5, 0.5) * span_y / s$zoom,
                        expand = TRUE, datum = NA) +
    ggplot2::labs(title = s$title, subtitle = s$subtitle, caption = s$caption) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(legend.position = s$legend_position,
                    legend.text = ggplot2::element_text(colour = s$legend_colour, family = s$legend_font),
                    legend.title = ggplot2::element_text(colour = s$legend_colour, family = s$legend_font),
                    plot.title = ggplot2::element_text(face = "bold", colour = s$high,
                                                       hjust = c(left = 0, middle = 0.5, right = 1)[[s$title_align]]),
                    plot.caption = ggplot2::element_text(hjust = 0, colour = "#555555"),
                    plot.margin = ggplot2::margin(15, 15, 15, 15),
                    panel.border = if (isTRUE(s$canvas_boundary))
                      ggplot2::element_rect(fill = NA, colour = "#666666", linewidth = 0.6)
                    else ggplot2::element_blank(),
                    plot.background = ggplot2::element_rect(fill = "white", colour = NA))
}

# Explicit units prevent surprising image sizes. JPEG is supported as jpg/jpeg.
export_map <- function(plot, filename, width = 10, height = 8, dpi = 300) {
  extension <- tolower(tools::file_ext(filename))
  if (!extension %in% c("png", "jpg", "jpeg", "pdf")) stop("Choose PDF, PNG or JPG.")
  if (any(!is.finite(c(width, height, dpi))) || width <= 0 || height <= 0 || dpi < 72) {
    stop("Use positive dimensions and a resolution of at least 72 DPI.")
  }
  if (width > 30 || height > 30 || dpi > 600) stop("Maximum export is 30 inches per side and 600 DPI.")
  ggplot2::ggsave(filename, plot = plot, width = width, height = height,
                  units = "in", dpi = dpi, bg = "white", device = extension)
  invisible(filename)
}
