# Start from this project folder with shiny::runApp('.').
# The helpers are independent of Shiny and can also be used in ordinary scripts.
source("R/load.R")
library(shiny)
council_profiles <- read_council_profiles()
default_profile <- get_council_profile(mapper_config$default_council)
council_choices <- stats::setNames(council_profiles$council_id, council_profiles$council_name)

# Small shared UI builders keep file/layer selection consistent in both panels.
layer_picker <- function(prefix) {
  tagList(uiOutput(paste0(prefix, "_file_ui")),
          uiOutput(paste0(prefix, "_layer_ui")))
}

# bslib supplies the responsive layout; the map itself uses ggplot2 throughout.
ui <- bslib::page_sidebar(
  title = mapper_config$app_name,
  theme = bslib::bs_theme(version = 5, primary = default_profile$primary_colour,
                          base_font = "system-ui"),
  tags$head(tags$style(HTML("
    .map-toolbar {
      display: flex;
      flex-wrap: wrap;
      align-items: flex-end;
      gap: .4rem;
    }
    .map-toolbar-nav {
      flex-wrap: nowrap;
      align-items: center;
      gap: .25rem;
      padding: .25rem .45rem .25rem 0;
    }
    .map-toolbar .btn {
      width: auto;
      min-width: 0;
      padding: .25rem .55rem;
      line-height: 1.25;
      white-space: nowrap;
    }
    .map-height-control {
      display: flex;
      align-items: center;
      gap: .35rem;
      margin-left: .35rem;
      white-space: nowrap;
    }
    .map-toolbar-nav .map-height-control {
      margin-left: .2rem;
    }
    .map-height-control > span {
      font-size: .78rem;
    }
    .map-height-control .form-group,
    .map-height-control .shiny-input-container {
      width: 92px;
      margin: 0;
    }
    .map-height-control .selectize-control {
      margin: 0;
    }
    .category-colour-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      column-gap: .6rem;
    }
    .category-colour-grid .shiny-input-container {
      width: 100%;
    }
    @media (max-width: 760px) {
      .map-height-control {
        margin-left: 0;
      }
    }
  "))),
  sidebar = bslib::sidebar(width = 350, id = "main_sidebar",
    h5("1 · Local files"),
    selectInput("council_profile", "Council profile", council_choices, selected = mapper_config$default_council),
    textInput("folder", "Input folder", council_map_dir(mapper_config$default_council)),
    actionButton("refresh", "Refresh files", class = "btn-outline-primary"),
    helpText("Paths refer to the computer running R. No files are uploaded."),
    layer_picker("base"),
    uiOutput("filter_column_ui"), uiOutput("filter_value_ui"),
    actionButton("load_base", "Load base polygons", class = "btn-primary"),
    hr(), h5("2 · Map appearance"),
    textInput("title", "Title", paste(default_profile$council_name, "area map")),
    selectInput("title_align", "Title alignment",
                c("Left" = "left", "Middle" = "middle", "Right" = "right"),
                selected = "middle"),
    textInput("subtitle", "Subtitle"),
    textAreaInput("caption", "Source, edition and overlay key", rows = 2,
                   placeholder = "Record boundary year, data source, and overlay symbols."),
    uiOutput("variable_ui"),
    selectInput("variable_type", "Colour selected column as",
                c("Numeric values" = "Numeric", "Categories" = "Categorical")),
    textInput("legend", "Legend title", "Value"),
    conditionalPanel("input.variable_type == 'Numeric'",
      selectInput("value_scale", "Indicator value scale",
                  c("Values as entered (20 means 20)" = "raw",
                    "Fractional percentage (0.2 means 20%)" = "fraction_percent")),
      helpText("Fractional percentages are converted to 0–100 for mapping; % is added automatically when the suffix is blank."),
      textInput("units", "Numeric suffix (for example %)"),
      numericInput("decimals", "Decimal places", 1, min = 0, max = 5, step = 1),
      selectInput("classification", "Colour classification",
                  c("Continuous", "Equal intervals", "Quantiles", "Fixed breaks")),
      numericInput("classes", "Number of bands", 5, min = 2, max = 9, step = 1),
      conditionalPanel("input.classification == 'Fixed breaks'",
        textInput("breaks", "Breaks, separated by commas", "0,20,40,60,80,100"))),
    uiOutput("category_colours_ui"),
    textInput("low", "Low colour (hex)", default_profile$light_colour),
    textInput("high", "High / plain map colour (hex)", default_profile$primary_colour),
    helpText(mapper_config$colour_note),
    textInput("missing", "Missing-data colour (hex)", mapper_config$missing_colour),
    sliderInput("base_alpha", "Base opacity", min = 0, max = 1, value = 1),
    numericInput("base_linewidth", "Polygon boundary thickness (mm)", 0.25, min = 0, max = 3, step = 0.05),
    textInput("base_boundary_colour", "Polygon boundary colour (hex)", "#FFFFFF"),
    helpText("Applies to the main map polygons. Set thickness to 0 to hide their boundaries."),
    checkboxInput("canvas_boundary", "Show map canvas boundary", FALSE),
    checkboxInput("labels", "Show base labels", FALSE), uiOutput("label_ui"),
    sliderInput("label_size", "Label size", min = 1, max = 6, value = 3, step = 0.5),
    textInput("label_colour", "Label text colour (hex)", "#000000"),
    selectInput("label_font", "Label font", c("Sans serif" = "sans", "Serif" = "serif", "Monospace" = "mono")),
    textInput("legend_colour", "Legend text colour (hex)", "#000000"),
    selectInput("legend_font", "Legend font", c("Sans serif" = "sans", "Serif" = "serif", "Monospace" = "mono")),
    selectInput("legend_position", "Legend position", c("right", "bottom", "left", "top", "none"))
  ),
  bslib::navset_card_tab(
    bslib::nav_panel("Map",
      p("Local GeoPackage mapping · polygon and point layers · report exports"),
      uiOutput("map_preview_ui"),
      helpText("Zoom and pan adjust the geographic view, including exports and R code. Use Expand canvas for full width.",
               "Height affects the screen only. Export uses the same map settings; labels may shift with output dimensions.",
               "Missing areas use the missing-data colour. Overlays draw above the base; labels draw last.")),
    bslib::nav_panel("Data",
      h4("Join area-level data"),
      p("CSV should contain one row per geography code. Check that its geography edition matches the boundaries."),
      fileInput("csv", "Indicator CSV", accept = ".csv"),
      uiOutput("join_keys_ui"),
      actionButton("join", "Join data"), actionButton("clear_data", "Remove joined data"),
      h5("Optional percentage from counts"), uiOutput("percentage_ui"),
      actionButton("percentage", "Calculate percentage"),
      helpText("Result is .map_percentage, on a 0–100 scale. Zero denominators become missing.",
               "Existing decimal fractions can be mapped using Fractional percentage in Map appearance."),
      h5("Join checks"), tableOutput("join_summary"), verbatimTextOutput("join_detail"),
      h5("Current attributes (first 10 areas)"), tableOutput("attributes")),
    bslib::nav_panel("Layers",
      h4("Add polygon or point overlays"),
      helpText("Load your base map once. Choose an overlay below and click Add layer. Repeat to add a second, third or further overlay; existing layers stay on the map. Loading base polygons again clears overlays."),
      textOutput("overlay_status"),
      layer_picker("overlay"),
      textInput("overlay_name", "Layer display name", "",
                placeholder = "Optional: defaults to the selected layer name"),
      textInput("overlay_colour", "Colour (hex)", "#333333"),
      sliderInput("overlay_alpha", "Opacity", 0, 1, 0.7),
      numericInput("overlay_size", "Point size", 2, min = 0.1, max = 10),
      numericInput("overlay_linewidth", "Polygon boundary thickness (mm)", 0.25, min = 0, max = 3, step = 0.05),
      selectInput("overlay_shape", "Point symbol", c("Circle" = 16, "Triangle" = 17, "Square" = 15)),
      checkboxInput("outline_only", "Polygon outline only", TRUE),
      selectInput("overlay_mode", "Area selection",
                  c("Full layer", "Intersecting features", "Clip to base")),
      uiOutput("overlay_label_ui"),
      helpText("To add another layer, choose its GeoPackage and layer above, set its appearance, then click Add layer again. Use different colours or symbols to distinguish overlays. Repeated names receive a number automatically."),
      actionButton("add_overlay", "Add layer", class = "btn-primary"),
      uiOutput("overlay_select_ui"),
      actionButton("remove_overlay", "Remove selected layer", class = "btn-outline-danger"),
      actionButton("toggle_overlay", "Show / hide selected layer"),
      actionButton("lower_overlay", "Send backward"), actionButton("raise_overlay", "Bring forward"),
      helpText("Send backward (Move lower) draws the selected layer behind the previous overlay. Bring forward (Move higher) draws it above the next overlay. This changes overlap order, not geographic position. Base polygons stay underneath."),
      hr(), h4("1 · Automatically assign layer colours"),
      textInput("ramp_low", "Ramp start colour (hex)", "#2166AC"),
      textInput("ramp_high", "Ramp end colour (hex)", "#B2182B"),
      actionButton("apply_layer_ramp", "Assign colour ramp to all overlays"),
      helpText("Assigns single colours in drawing order, including hidden layers. Then adjust individual layers below."),
      h4("2 · Adjust an individual layer"),
      tableOutput("overlay_table"),
      numericInput("edit_overlay_linewidth", "Selected polygon boundary thickness (mm)", 0.25, min = 0, max = 3, step = 0.05),
      actionButton("update_overlay_width", "Apply boundary thickness"),
      textInput("edit_overlay_colour", "Selected layer colour (hex)", "#333333"),
      uiOutput("overlay_value_ui"),
      textInput("edit_overlay_low", "Value ramp low colour (hex)", "#EFF7EE"),
      textInput("edit_overlay_high", "Value ramp high colour (hex)", "#007A3D"),
      helpText("A value ramp uses five equal-interval bands for polygon fills and outlines or point symbols, with a legend for each layer. Value ramps fill polygons even if they were added as outline only."),
      actionButton("update_overlay_colour", "Apply layer colours"),
      uiOutput("overlay_ramp_keys"),
      helpText("Rows are in drawing order: the last row is on top. Select a layer to edit its colours.",
               "Visible overlays have a Layers legend. Use the caption for sources and extra explanation.")),
    bslib::nav_panel("Export & settings",
      h4("Export current map"),
      selectInput("format", "File format", c("png", "pdf", "jpg")),
      numericInput("width", "Width (inches)", 10, min = 1, max = 30),
      numericInput("height", "Height (inches)", 8, min = 1, max = 30),
      numericInput("dpi", "Image resolution (DPI)", 300, min = 72, max = 600),
      downloadButton("export", "Download map"),
      hr(), h4("Reusable appearance settings"),
      downloadButton("save_settings", "Save appearance JSON"),
      fileInput("restore_settings", "Load appearance JSON", accept = ".json"),
      helpText("Appearance settings save colours, indicator/label column names and layout.",
               "They do not save input files, selections, joins or overlays. Reload these separately.")),
    bslib::nav_panel("R code",
      p("Run this code from the thurrock-mapper working directory. It reflects the loaded map, including filters, joins, layer order, zoom and appearance."),
      p("Uploaded CSV data is embedded in the script. Boundary files must remain at their recorded paths."),
      downloadButton("download_code", "Download R script"), verbatimTextOutput("reproduction_code")),
    bslib::nav_panel("Help",
      h4("Quick start"),
      tags$ol(tags$li("Select a council profile, then refresh its GeoPackage list."),
              tags$li("Choose a file and polygon layer. Optionally filter an attribute, then load it."),
              tags$li("Use Data to join a CSV by geography code; review the join checks."),
              tags$li("Choose an indicator and colours. Add point or polygon overlays in Layers."),
              tags$li("Record sources, boundary edition and overlay symbols in the caption; export.")),
      p("No example data? Run source('scripts/02_create_demo.R') once in R, then refresh."),
      p("Detailed help: docs/USER_GUIDE.md. Code walkthrough: docs/CODE_GUIDE.md."),
      p("Add councils in config/councils.csv and config/council_source_filters.csv."),
      p("Download configured boundaries with scripts/03_download_boundaries.R."),
      p("Version 1 does not infer geography editions, official membership or matching codes.")),
    bslib::nav_spacer(),
    bslib::nav_item(
      tags$div(class = "map-toolbar map-toolbar-nav",
        actionButton("zoom_in", "+ Zoom", class = "btn-sm btn-outline-secondary",
                     title = "Zoom in"),
        actionButton("zoom_out", "− Zoom", class = "btn-sm btn-outline-secondary",
                     title = "Zoom out"),
        actionButton("reset_view", "Fit", class = "btn-sm btn-outline-secondary",
                     title = "Fit the whole base map"),
        actionButton("toggle_canvas_size", "Expand canvas",
                     class = "btn-sm btn-outline-primary",
                     title = "Hide the control pane and give the map the full browser width"),
        actionButton("pan_left", "←", class = "btn-sm btn-outline-secondary",
                     title = "Move the map left"),
        actionButton("pan_right", "→", class = "btn-sm btn-outline-secondary",
                     title = "Move the map right"),
        actionButton("pan_up", "↑", class = "btn-sm btn-outline-secondary",
                     title = "Move the map up"),
        actionButton("pan_down", "↓", class = "btn-sm btn-outline-secondary",
                     title = "Move the map down"),
        tags$div(class = "map-height-control",
          tags$span("Height"),
          selectInput("preview_height", NULL,
                      choices = c("650 px" = 650, "800 px" = 800,
                                  "900 px" = 900, "1100 px" = 1100,
                                  "1400 px" = 1400), selected = 900)
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # Session-specific objects prevent one analyst's data leaking into another session.
  state <- reactiveValues(catalogue = data.frame(), base = NULL, map_data = NULL,
                          csv = NULL, diagnostics = NULL, overlays = list(),
                          base_code = character(), data_code = character(),
                          category_colours = list())

  view <- reactiveValues(zoom = 1, centre_x = 0.5, centre_y = 0.5)
  reset_view <- function() { view$zoom <- 1; view$centre_x <- 0.5; view$centre_y <- 0.5 }
  observeEvent(input$zoom_in, { view$zoom <- min(16, view$zoom * 1.25) })
  observeEvent(input$zoom_out, { view$zoom <- max(0.5, view$zoom / 1.25) })
  observeEvent(input$reset_view, reset_view())
  observeEvent(input$toggle_canvas_size, {
    bslib::toggle_sidebar("main_sidebar", open = !isTRUE(input$main_sidebar), session = session)
  })
  observeEvent(input$main_sidebar, {
    updateActionButton(session, "toggle_canvas_size",
                       label = if (isTRUE(input$main_sidebar)) "Expand canvas" else "Show controls")
  }, ignoreInit = FALSE)
  pan <- function(axis, direction) {
    view[[axis]] <- max(0, min(1, view[[axis]] + direction * 0.15 / view$zoom))
  }
  # Arrow buttons describe movement of the map content, rather than the viewport.
  observeEvent(input$pan_left, pan("centre_x", 1))
  observeEvent(input$pan_right, pan("centre_x", -1))
  observeEvent(input$pan_up, pan("centre_y", -1))
  observeEvent(input$pan_down, pan("centre_y", 1))
  output$map_preview_ui <- renderUI({
    plotOutput("map", height = paste0(input$preview_height %||% 900, "px"))
  })

  # Present a readable notification for all expected file/data errors.
  safely <- function(expr) {
    tryCatch(force(expr), error = function(e) {
      showNotification(conditionMessage(e), type = "error", duration = 12)
      invisible(NULL)
    })
  }
  check_colour <- function(value) {
    if (length(value) != 1 || !grepl("^#[0-9A-Fa-f]{6}$", value)) {
      stop("Colours must be six-digit hex codes, for example #007A3D.")
    }
    value
  }
  refresh_files <- function() safely({
    if (!dir.exists(input$folder)) {
      state$catalogue <- data.frame()
      showNotification("This council folder does not exist yet. Run the boundary downloader first.", type = "warning")
    } else state$catalogue <- list_map_layers(input$folder)
  })
  observeEvent(input$refresh, refresh_files())
  observeEvent(TRUE, refresh_files(), once = TRUE)

  observeEvent(input$council_profile, {
    profile <- get_council_profile(input$council_profile)
    folder <- council_map_dir(input$council_profile)
    updateTextInput(session, "folder", value = folder)
    updateTextInput(session, "title", value = paste(profile$council_name, "area map"))
    updateTextInput(session, "low", value = profile$light_colour)
    updateTextInput(session, "high", value = profile$primary_colour)
    reset_view()
    state$base <- NULL; state$map_data <- NULL; state$csv <- NULL
    state$diagnostics <- NULL; state$overlays <- list(); state$category_colours <- list()
    state$catalogue <- if (dir.exists(folder)) list_map_layers(folder) else data.frame()
    showNotification(paste("Council profile changed to", profile$council_name,
      ". Loaded data and layers were cleared."), type = "message")
  }, ignoreInit = TRUE)

  # Each picker exposes file paths and then the layers belonging to that file.
  for (prefix_value in c("base", "overlay")) local({
    prefix <- prefix_value
    output[[paste0(prefix, "_file_ui")]] <- renderUI({
      catalogue <- state$catalogue
      if (!nrow(catalogue)) return(helpText("No GeoPackages found. Add files and refresh."))
      paths <- unique(catalogue$file)
      selectInput(paste0(prefix, "_file"), "GeoPackage", stats::setNames(paths, basename(paths)))
    })
    output[[paste0(prefix, "_layer_ui")]] <- renderUI({
      req(input[[paste0(prefix, "_file")]])
      layers <- state$catalogue$layer[state$catalogue$file == input[[paste0(prefix, "_file")]]]
      selectInput(paste0(prefix, "_layer"), "Layer", layers)
    })
  })

  # Read the candidate base before offering filter controls. It is not yet applied.
  candidate_base <- reactive({
    req(input$base_file, input$base_layer)
    tryCatch(load_map_layer(input$base_file, input$base_layer),
             error = function(e) {validate(need(FALSE, conditionMessage(e)))})
  })
  output$filter_column_ui <- renderUI({
    x <- candidate_base()
    selectInput("filter_column", "Optional attribute filter",
                 c("Use whole layer" = "", names(sf::st_drop_geometry(x))))
  })
  output$filter_value_ui <- renderUI({
    req(input$filter_column)
    values <- sort(unique(as.character(candidate_base()[[input$filter_column]])))
    tagList(
      helpText("All values are selected initially. Remove any values you want to exclude, or clear the selection to choose a subset."),
      actionButton("filter_select_all", "Select all"), actionButton("filter_clear_all", "Clear all"),
      selectizeInput("filter_values", "Keep values (exact match)", values, selected = values,
        multiple = TRUE, options = list(plugins = list("remove_button"))))
  })
  observeEvent(input$filter_select_all, {
    req(input$filter_column)
    updateSelectizeInput(session, "filter_values", selected = sort(unique(as.character(candidate_base()[[input$filter_column]]))))
  })
  observeEvent(input$filter_clear_all, {
    updateSelectizeInput(session, "filter_values", selected = character())
  })
  observeEvent(input$load_base, safely({
    x <- candidate_base()
    if (nzchar(input$filter_column %||% "")) {
      x <- select_map_area(x, input$filter_column, input$filter_values)
    }
    if (!all(as.character(sf::st_geometry_type(x)) %in% c("POLYGON", "MULTIPOLYGON"))) {
      stop("Choose polygons for the base; add points in Layers.")
    }
    state$base_code <- c(
      paste0("base <- load_map_layer(", r_literal(input$base_file), ", ", r_literal(input$base_layer), ")"),
      if (nzchar(input$filter_column %||% "")) paste0("base <- select_map_area(base, ", r_literal(input$filter_column), ", ", r_literal(input$filter_values), ")"))
    state$data_code <- character()
    reset_view()
    state$base <- x
    state$map_data <- x
    state$diagnostics <- NULL
    state$overlays <- list()
    state$category_colours <- list()
    showNotification("Base loaded. Previous data joins and overlays were cleared.", type = "message")
  }))

  # Keep indicator/label dropdowns aligned with currently loaded attributes.
  output$variable_ui <- renderUI({
    columns <- if (is.null(state$map_data)) character() else names(sf::st_drop_geometry(state$map_data))
    selectInput("variable", "Indicator column", c("Plain boundary map" = "", columns))
  })
  output$label_ui <- renderUI({
    columns <- if (is.null(state$map_data)) character() else names(sf::st_drop_geometry(state$map_data))
    selectInput("label", "Label column", c("None" = "", columns))
  })
  category_values <- reactive({
    req(state$map_data, input$variable_type == "Categorical", input$variable)
    values <- trimws(as.character(state$map_data[[input$variable]]))
    sort(unique(values[!is.na(values) & nzchar(values)]))
  })
  output$category_colours_ui <- renderUI({
    categories <- category_values()
    if (!length(categories)) return(helpText("The selected column has no categories to colour."))
    saved <- state$category_colours[[input$variable]] %||% list()
    colours <- category_palette(categories, saved)
    tagList(
      h6("Category colours"),
      helpText("Edit any six-digit hex colour, then apply. Categories not changed keep their preset colours."),
      tags$div(class = "category-colour-grid",
        lapply(seq_along(categories), function(i) {
          textInput(paste0("category_colour_", i), categories[[i]], unname(colours[[i]]))
        })),
      actionButton("apply_category_colours", "Apply category colours", class = "btn-primary"),
      actionButton("reset_category_colours", "Reset preset colours", class = "btn-outline-secondary")
    )
  })
  observeEvent(input$apply_category_colours, safely({
    categories <- category_values()
    colours <- vapply(seq_along(categories), function(i) {
      check_colour(input[[paste0("category_colour_", i)]])
    }, character(1))
    names(colours) <- categories
    all_colours <- state$category_colours
    all_colours[[input$variable]] <- as.list(colours)
    state$category_colours <- all_colours
    showNotification("Category colours applied.", type = "message")
  }))
  observeEvent(input$reset_category_colours, {
    req(input$variable)
    all_colours <- state$category_colours
    all_colours[[input$variable]] <- NULL
    state$category_colours <- all_colours
    showNotification("Preset category colours restored.", type = "message")
  })

  # Uploaded CSVs remain session-local; no copies are saved in the project.
  observeEvent(input$csv, safely({
    state$csv <- NULL
    state$csv <- read_indicator_data(input$csv$datapath)
  }))
  output$join_keys_ui <- renderUI({
    req(state$base, state$csv)
    tagList(selectInput("boundary_key", "Boundary geography code", names(sf::st_drop_geometry(state$base))),
            selectInput("data_key", "CSV geography code", names(state$csv)))
  })
  observeEvent(input$join, safely({
    req(state$base, state$csv, input$boundary_key, input$data_key)
    result <- join_map_data(state$base, state$csv, input$boundary_key, input$data_key)
    state$data_code <- c(paste0("indicator_data <- ", r_literal(as.data.frame(lapply(state$csv, identity), stringsAsFactors = FALSE))),
      paste0("map_data <- join_map_data(base, indicator_data, ", r_literal(input$boundary_key), ", ", r_literal(input$data_key), ")$map"))
    state$map_data <- result$map
    state$diagnostics <- result
    showNotification("Join complete. Review the join checks before mapping.", type = "message")
  }))
  observeEvent(input$clear_data, {
    req(state$base)
    state$map_data <- state$base
    state$data_code <- character()
    state$diagnostics <- NULL
  })
  output$percentage_ui <- renderUI({
    req(state$map_data)
    columns <- names(sf::st_drop_geometry(state$map_data))
    tagList(selectInput("numerator", "Numerator column", columns),
            selectInput("denominator", "Denominator column", columns))
  })
  observeEvent(input$percentage, safely({
    req(state$map_data, input$numerator, input$denominator)
    x <- state$map_data
    x$.map_percentage <- calculate_percentage(x[[input$numerator]], x[[input$denominator]])
    state$data_code <- c(state$data_code, paste0("map_data$.map_percentage <- calculate_percentage(map_data[[",
      r_literal(input$numerator), "]], map_data[[", r_literal(input$denominator), "]])"))
    state$map_data <- x
    showNotification("Created .map_percentage; select it as the indicator.", type = "message")
  }))
  output$join_summary <- renderTable({req(state$diagnostics); state$diagnostics$summary})
  output$join_detail <- renderPrint({
    req(state$diagnostics)
    cat("Boundary codes without CSV data:\n")
    print(state$diagnostics$missing_codes)
    cat("CSV codes unused by the selected boundaries:\n")
    print(state$diagnostics$unused_codes)
  })
  output$attributes <- renderTable({req(state$map_data); head(sf::st_drop_geometry(state$map_data), 10)})

  # Load extra geometries only when requested, and capture their individual style.
  candidate_overlay <- reactive({
    req(input$overlay_file, input$overlay_layer)
    # A file change can arrive before its replacement layer selector updates.
    req(input$overlay_layer %in% sf::st_layers(input$overlay_file)$name)
    tryCatch(load_map_layer(input$overlay_file, input$overlay_layer),
             error = function(e) {validate(need(FALSE, conditionMessage(e)))})
  })
  output$overlay_label_ui <- renderUI({
    x <- candidate_overlay()
    selectInput("overlay_label", "Overlay label", c("None" = "", names(sf::st_drop_geometry(x))))
  })
  observeEvent(input$add_overlay, safely({
    if (is.null(state$base)) stop("Load base polygons once before adding overlay layers.")
    req(input$overlay_file, input$overlay_layer)
    if (!input$overlay_layer %in% sf::st_layers(input$overlay_file)$name) {
      stop("The layer list is updating. Choose a layer from the selected GeoPackage, then click Add layer again.")
    }
    x <- restrict_overlay(candidate_overlay(), state$base, input$overlay_mode)
    if (!nrow(x)) stop("No overlay features remain after selection.")
    check_colour(input$overlay_colour)
    name <- trimws(input$overlay_name %||% "")
    if (!nzchar(name) || identical(name, "Additional layer")) name <- input$overlay_layer
    existing_names <- vapply(state$overlays, function(item) item$name, character(1))
    stem <- name; number <- 2L
    while (name %in% existing_names) {
      name <- paste0(stem, " (", number, ")")
      number <- number + 1L
    }
    if (!is.finite(input$overlay_size) || input$overlay_size <= 0) stop("Enter a positive overlay size.")
    linewidth <- input$overlay_linewidth %||% 0.25
    if (!is.finite(linewidth) || linewidth < 0 || linewidth > 3) stop("Boundary thickness must be between 0 and 3 mm.")
    item <- list(data = x, name = name, visible = TRUE,
                 colour = input$overlay_colour, alpha = input$overlay_alpha,
                 size = input$overlay_size, shape = as.integer(input$overlay_shape),
                 linewidth = linewidth,
                 outline_only = input$outline_only, label = input$overlay_label %||% "",
                 variable = "", low = "#EFF7EE", high = "#007A3D",
                 source_file = input$overlay_file, source_layer = input$overlay_layer,
                 selection_mode = input$overlay_mode)
    state$overlays <- c(state$overlays, list(item))
    showNotification(paste0("Added ", name, ". ", length(state$overlays),
      " overlay layer(s) on the map. Choose another file/layer and click Add layer to add more."),
      type = "message", duration = 6)
  }))
  output$overlay_status <- renderText({
    total <- length(state$overlays)
    visible <- sum(vapply(state$overlays, function(x) isTRUE(x$visible), logical(1)))
    paste0(total, " added overlay layer(s); ", visible, " visible. Base map is separate.")
  })
  output$overlay_table <- renderTable({
    if (!length(state$overlays)) return(data.frame(Status = "No overlays added"))
    dplyr::bind_rows(lapply(seq_along(state$overlays), function(i) {
      x <- state$overlays[[i]]
      data.frame(Order = i, Name = x$name, Visible = x$visible,
                  Colour = x$colour, Features = nrow(x$data))
    }))
  })
  output$overlay_select_ui <- renderUI({
    if (!length(state$overlays)) return(NULL)
    labels <- vapply(state$overlays, function(x) x$name, character(1))
    selectInput("selected_overlay", "Layer to change",
                 stats::setNames(seq_along(labels), paste(seq_along(labels), labels)),
                 selected = min(as.integer(isolate(input$selected_overlay) %||% 1), length(labels)))
  })
  selected_overlay <- reactive({
    req(input$selected_overlay)
    i <- as.integer(input$selected_overlay)
    req(i >= 1, i <= length(state$overlays))
    i
  })
  output$overlay_value_ui <- renderUI({
    i <- selected_overlay(); item <- state$overlays[[i]]
    selectInput("edit_overlay_variable", "Colour areas / points by numeric value",
      c("Single layer colour" = "", names(sf::st_drop_geometry(item$data))), selected = item$variable)
  })
  observeEvent(list(input$selected_overlay, state$overlays), {
    item <- state$overlays[[selected_overlay()]]
    updateTextInput(session, "edit_overlay_colour", value = item$colour)
    updateTextInput(session, "edit_overlay_low", value = item$low)
    updateTextInput(session, "edit_overlay_high", value = item$high)
    updateNumericInput(session, "edit_overlay_linewidth", value = item$linewidth %||% 0.25)
  })
  observeEvent(input$update_overlay_width, safely({
    i <- selected_overlay(); layers <- state$overlays
    width <- input$edit_overlay_linewidth
    if (length(width) != 1 || !is.finite(width) || width < 0 || width > 3) stop("Boundary thickness must be between 0 and 3 mm.")
    layers[[i]]$linewidth <- width
    state$overlays <- layers
  }))
  observeEvent(input$update_overlay_colour, safely({
    i <- selected_overlay(); layers <- state$overlays
    item <- layers[[i]]
    item$colour <- check_colour(input$edit_overlay_colour)
    item$low <- check_colour(input$edit_overlay_low)
    item$high <- check_colour(input$edit_overlay_high)
    item$variable <- input$edit_overlay_variable %||% ""
    if (nzchar(item$variable)) overlay_value_colours(item, settings()$missing)
    layers[[i]] <- item; state$overlays <- layers
  }))
  observeEvent(input$apply_layer_ramp, safely({
    req(length(state$overlays))
    colours <- grDevices::colorRampPalette(c(check_colour(input$ramp_low), check_colour(input$ramp_high)))(length(state$overlays))
    layers <- state$overlays
    for (i in seq_along(layers)) { layers[[i]]$colour <- colours[[i]]; layers[[i]]$variable <- "" }
    state$overlays <- layers
    if (!is.null(input$selected_overlay)) updateTextInput(session, "edit_overlay_colour", value = layers[[selected_overlay()]]$colour)
  }))
  output$overlay_ramp_keys <- renderUI({
    items <- Filter(function(x) isTRUE(x$visible) && nzchar(x$variable), state$overlays)
    tagList(lapply(items, function(item) {
      values <- numeric_indicator(item$data[[item$variable]])
      limits <- range(values[is.finite(values)])
      tagList(tags$strong(paste(item$name, "-", item$variable)),
        tags$div(style = paste0("height:16px;background:linear-gradient(to right,", item$low, ",", item$high, ");")),
        p(paste(format(limits[1]), "to", format(limits[2]))))
    }))
  })
  observeEvent(input$toggle_overlay, {
    i <- selected_overlay(); layers <- state$overlays
    layers[[i]]$visible <- !layers[[i]]$visible
    state$overlays <- layers
  })
  observeEvent(input$remove_overlay, {
    i <- selected_overlay(); state$overlays <- state$overlays[-i]
    updateSelectInput(session, "selected_overlay", selected = min(i, length(state$overlays)))
  })
  move_overlay <- function(direction) {
    i <- selected_overlay(); j <- i + direction
    if (j < 1 || j > length(state$overlays)) return(invisible(NULL))
    layers <- state$overlays
    layers[c(i, j)] <- layers[c(j, i)]
    state$overlays <- layers
    updateSelectInput(session, "selected_overlay", selected = j)
  }
  observeEvent(input$lower_overlay, move_overlay(-1))
  observeEvent(input$raise_overlay, move_overlay(1))

  r_literal <- function(value) paste(capture.output(dput(value)), collapse = "\n")
  reproduction_code <- reactive({
    req(state$map_data)
    lines <- c('# Run from the thurrock-mapper project directory.', 'source("R/load.R")',
      state$base_code, 'map_data <- base', state$data_code, 'overlays <- list()')
    for (i in seq_along(state$overlays)) {
      item <- state$overlays[[i]]
      style <- item[setdiff(names(item), c("data", "source_file", "source_layer", "selection_mode"))]
      lines <- c(lines,
        paste0("overlay_data <- load_map_layer(", r_literal(item$source_file), ", ", r_literal(item$source_layer), ")"),
        paste0("overlay_data <- restrict_overlay(overlay_data, base, ", r_literal(item$selection_mode), ")"),
        paste0("overlays[[", i, "]] <- ", r_literal(style)), paste0("overlays[[", i, "]]$data <- overlay_data"))
    }
    paste(c(lines, paste0("settings <- ", r_literal(settings())), "plot <- build_map(map_data, overlays, settings)",
      "print(plot)", paste0("export_map(plot, ", r_literal(paste0("area-map.", input$format)),
      ", width = ", input$width, ", height = ", input$height, ", dpi = ", input$dpi, ")")), collapse = "\n\n")
  })
  output$reproduction_code <- renderText(reproduction_code())
  output$download_code <- downloadHandler(filename = function() "reproduce-map.R",
    content = function(file) writeLines(reproduction_code(), file))

  # Collect appearance settings once, then share them between preview and download.
  settings <- reactive({
    keys <- names(default_map_settings())
    result <- lapply(keys, function(key) input[[key]] %||% default_map_settings()[[key]])
    names(result) <- keys
    result$zoom <- view$zoom; result$centre_x <- view$centre_x; result$centre_y <- view$centre_y
    result$category_colours <- if (identical(result$variable_type, "Categorical") && nzchar(result$variable)) {
      state$category_colours[[result$variable]] %||% list()
    } else list()
    for (key in c("low", "high", "missing", "label_colour", "legend_colour", "base_boundary_colour")) check_colour(result[[key]])
    result
  })
  current_plot <- reactive({
    req(state$map_data)
    build_map(state$map_data, state$overlays, settings())
  })
  output$map <- renderPlot({
    validate(need(!is.null(state$map_data), "Choose and load base polygons to begin."))
    tryCatch(print(current_plot()), error = function(e) validate(need(FALSE, conditionMessage(e))))
  }, res = 110)
  output$export <- downloadHandler(
    filename = function() paste0("area-map.", input$format),
    content = function(file) {
      # Shiny gives a temporary path without the requested extension.
      target <- paste0(file, ".", input$format)
      on.exit(unlink(target), add = TRUE)
      export_map(current_plot(), target, input$width, input$height, input$dpi)
      if (!file.copy(target, file, overwrite = TRUE)) stop("Could not prepare export.")
    }
  )
  output$save_settings <- downloadHandler(
    filename = function() "map-appearance.json",
    content = function(file) jsonlite::write_json(list(version = 1, appearance = settings()),
                                                  file, auto_unbox = TRUE, pretty = TRUE)
  )
  observeEvent(input$restore_settings, safely({
    saved <- jsonlite::read_json(input$restore_settings$datapath, simplifyVector = TRUE)
    if (!identical(as.integer(saved$version), 1L) || !is.list(saved$appearance)) stop("Unsupported settings file.")
    s <- saved$appearance
    defaults <- default_map_settings()
    # Whitelist and type-check settings: JSON is data and is never evaluated as R.
    if (!all(names(s) %in% names(defaults))) stop("Unrecognised appearance setting.")
    if ("category_colours" %in% names(s)) {
      category_colours <- unlist(s$category_colours, use.names = TRUE)
      if (length(category_colours) && (is.null(names(category_colours)) ||
          any(!nzchar(names(category_colours))) || any(!grepl("^#[0-9A-Fa-f]{6}$", category_colours)))) {
        stop("Invalid setting: category_colours")
      }
      s$category_colours <- as.list(category_colours)
    }
    for (key in setdiff(names(s), "category_colours")) {
      if (length(s[[key]]) != 1 || is.na(s[[key]]) ||
          typeof(s[[key]]) != typeof(defaults[[key]]) &&
          !(is.numeric(s[[key]]) && is.numeric(defaults[[key]]))) stop("Invalid setting: ", key)
    }
    for (key in intersect(c("low", "high", "missing", "label_colour", "legend_colour", "base_boundary_colour"), names(s))) check_colour(s[[key]])
    for (key in names(s)) {
      if (key %in% c("zoom", "centre_x", "centre_y")) {
        view[[key]] <- s[[key]]
      } else if (key == "category_colours") {
        target_variable <- s$variable %||% input$variable %||% ""
        if (nzchar(target_variable)) {
          all_colours <- state$category_colours
          all_colours[[target_variable]] <- s[[key]]
          state$category_colours <- all_colours
        }
      } else if (key %in% c("labels", "canvas_boundary")) {
        updateCheckboxInput(session, key, value = s[[key]])
      } else if (key %in% c("base_alpha", "label_size")) {
        updateSliderInput(session, key, value = s[[key]])
      } else if (key %in% c("classes", "decimals", "base_linewidth")) {
        updateNumericInput(session, key, value = s[[key]])
      } else if (key %in% c("variable", "label", "variable_type", "value_scale", "classification", "legend_position",
                            "label_font", "legend_font", "title_align")) {
        updateSelectInput(session, key, selected = s[[key]])
      } else {
        updateTextInput(session, key, value = s[[key]])
      }
    }
    showNotification("Appearance loaded. Inputs, joins and overlays are unchanged.", type = "message")
  }))
}

# A tiny NULL helper avoids attaching another dependency just for this operator.
`%||%` <- function(x, alternative) if (is.null(x)) alternative else x
shinyApp(ui, server)
