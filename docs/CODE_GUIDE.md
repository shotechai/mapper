# Code and process guide

## Structure

This is a script-based Shiny project, not an R package. Open the project root before sourcing scripts. Each code block has a comment explaining its purpose. Dependencies use `package::function`, except Shiny, which is attached in `app.R` for readable UI code. `dplyr` and `readr` provide the tidyverse elements without loading the entire tidyverse.

| File | Responsibility |
|---|---|
| `app.R` | UI controls, session state and event handling |
| `R/load.R` | Check dependencies and source reusable helpers |
| `R/config.R` | Folder, CRS and default colours |
| `R/io.R` | Discover/load local layers, select areas and download optional files |
| `R/data.R` | Read CSVs, validate joins and calculate percentages |
| `R/map.R` | Classify values, build the map and export it |
| `scripts/01_install.R` | Install missing packages |
| `scripts/02_create_demo.R` | Create repeatable fictional teaching inputs |
| `scripts/03_download_boundaries.R` | Download all boundary editions for the default council profile |
| `scripts/04_script_example.R` | End-to-end mapping without the app |
| `config/boundary_sources.csv` | Reusable ONS service and edition metadata |
| `config/councils.csv` | Council names, slugs and starting colours |
| `config/council_source_filters.csv` | Edition-specific LAD filters per council |
| `tests/` | Functional checks using synthetic data |
| `.github/workflows/check-r.yml` | Dependency installation, tests and demo checks on GitHub |

## Processing sequence

1. `list_map_layers()` discovers GeoPackages and their internal layer names.
2. `load_map_layer()` reads one layer, requires a CRS, drops Z/M dimensions, repairs geometries, removes empty geometries and transforms to EPSG:27700.
3. `select_map_area()` optionally filters an existing attribute by exact values.
4. `join_map_data()` joins an indicator table and returns diagnostics.
5. Optional `calculate_percentage()` creates a new indicator.
6. Overlay files are read with the same loader and optionally restricted to the base.
7. `build_map()` combines base geometry, indicators, overlays and appearance into one ggplot object.
8. `export_map()` saves that object at specified dimensions and DPI.

EPSG:27700 suits this initial England workflow. Change the configured CRS deliberately before adapting the toolkit to another region. Transforming coordinates cannot fix an incorrectly assigned source CRS.

## Inputs and function results

`list_map_layers(folder)` returns a data frame containing file, layer and geometry. `load_map_layer(file, layer)` returns an `sf` object: a regular attribute table plus its geometry column. Most tidyverse table operations work with it; `sf::st_drop_geometry()` gives just the attributes.

`join_map_data(boundaries, data, boundary_key, data_key)` returns a list:

- `map`: the joined `sf` object.
- `summary`: counts of matched, unmatched and unused records.
- `missing_codes`, `unused_codes`: the actual codes to investigate.

Codes are trimmed and treated as text. Duplicate and missing keys stop the join. A one-to-one check prevents accidental multiplication of polygons. Added data columns are prefixed `data_` and checked for collisions. No fuzzy name matching, edition conversion or automatic aggregation occurs.

`numeric_indicator()` converts plain numeric strings and preserves missing values. It rejects suppression symbols, percent signs and infinite values. Such cleaning belongs in an explicit analytical step.

`calculate_percentage()` requires equal-length count vectors. Zero denominators remain unknown, rather than becoming zero percent. This function calculates proportions where the numerator is a subset of the denominator; it is not a general rate-per-population function.

## Plot design

`default_map_settings()` documents the appearance fields in one place. `build_map()` accepts that list plus a base `sf` object and a list of overlays. The example script shows the complete overlay structure.

Each overlay stores `data`, `name`, `visible`, `colour`, `size`, `alpha`, `shape`, `outline_only` and `label`. Its size is constant per layer. Mapping point sizes/colours to extra variables is outside this first version. The list order determines drawing order; names must be unique for the legend.

The base fill scale represents the indicator. A separate colour scale provides overlay legend entries. Quantiles use unique cut points, so tied observations may reduce the number of bands. Fixed breaks must span all finite observations. Missing fill uses an explicit colour; describe it in the caption because a continuous colour bar does not provide a separate missing-data key.

The preview is intentionally static. `ggplot2` was chosen instead of separate Leaflet/tmap renderers to keep one understandable plotting implementation for both preview and export. There is no pan/zoom or click-to-inspect interface yet. An interactive renderer could be added later without changing the loading and joining helpers.

## Shiny state and reactivity

`reactiveValues()` inside `server()` stores each session's catalogue, base, joined data, CSV, diagnostics and overlays. These are not shared global data objects.

Candidate base/overlay reactives read the currently selected layer to populate controls. Loading a base or adding an overlay requires a button click. The loaded base remains unchanged until its button is clicked again. A new base clears joins and overlays to prevent accidental mixing of areas.

`settings()` gathers current appearance inputs. `current_plot()` creates the common plot. `renderPlot()` displays it and the download handler passes it to `export_map()`. Expected input errors become readable notifications or plot validation messages.

JSON appearance files are read as data, never executed as R. Recognised fields and basic types are checked before updating inputs. They are style presets, not complete project snapshots. Full project restoration would need file provenance, selections, join keys and overlay instructions, plus checks that those inputs still exist.

## Download design and provenance

The configured downloader queries official ONS ArcGIS FeatureServers, requests
object IDs first to handle record limits, and writes one council-specific GeoPackage
per geography edition. LA and wards use profile-specific LAD-code filters.
OA/LSOA/MSOA services are spatially queried around the selected LAD and retained when their
point-on-surface lies inside it. A manifest records the returned feature counts and
source services. The legacy direct-file downloader still accepts HTTPS GeoPackages
or ZIP archives and validates them before copying.

## Testing and reproducibility

From the project root:

```r
source("scripts/01_install.R")
source("tests/run_tests.R")
source("scripts/02_create_demo.R")   # Once, when the demo does not already exist
source("scripts/04_script_example.R")
```

Tests target multi-layer file handling, CRS alignment, join failures, missing/zero handling, percentages, classifications, overlays, three export formats and overwrite protection. GitHub Actions also constructs the Shiny app and exercises the example script. A real browser review and real inputs for each operational council profile are still required; app construction alone does not validate every UI interaction.

Package versions are not pinned yet: installation uses the available CRAN releases. Once tests pass in the intended R setup, `renv::init()` and `renv::snapshot()` can record a verified environment. Commit `renv.lock` and the generated bootstrap files; do not commit the package library. No lockfile has been invented in the absence of an installed R environment.

## GitHub and future hosting

Commit project code and documentation, excluding private inputs and generated exports. Choose an open-source licence before distributing for reuse. Publish an example catalogue only with verified URLs, metadata and attribution.

Local folder selection is intended for trusted analysts running their own R process. For shared hosting, replace arbitrary folder entry with an allowlisted server directory or uploads; add authentication, file limits and operational logging. Keep the functions unchanged where possible and adapt file access in the UI. Never treat the current UI as a secured public file service.

Useful next improvements, after validating this version: official boundary catalogues/lookups, full project recipes, mapped point attributes, interactive preview and an approved deployment configuration.
