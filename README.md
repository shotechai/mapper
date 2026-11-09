# Mapper

A reusable R Shiny mapping toolkit for local authorities. Load boundaries, join a CSV, add polygon and point layers, change colours and labels, and export PDF, PNG or JPG. The same functions also work in R scripts. Thurrock is the first configured council profile, not a constraint in the mapping code.

**Status:** locally validated with R 4.4.1. The configured ONS downloader includes current, previous and December 2019 Thurrock ward boundaries alongside the requested LA and Census geographies. The profile-aware Shiny app constructed successfully.

## Start in RStudio

Install R (4.3 or newer recommended) and RStudio. Open `Mapper.Rproj`, then run in the R console:

```r
source("scripts/01_install.R")       # Install missing packages once
source("scripts/02_create_demo.R")   # Optional fictional demo, run once
shiny::runApp(".")                  # Launch in your browser
```

For your own maps, select a council profile and click **Refresh files**. Profile boundaries live in `data/input/map/<council-slug>/`. Choose a polygon layer and click **Load base polygons**. See the [user guide](docs/USER_GUIDE.md) for the remaining steps.

## What is included

New local overlays: demo maps for practice. Verify all maps before use.
Use **Refresh files**, then add them from **Layers**.

- Council profiles separated from a reusable ONS boundary-source catalogue.
- A configured Thurrock starter profile and a path for adding other councils.
- Multiple layers per GeoPackage, attribute selection and common-CRS handling.
- Checked CSV joins, unmatched-code reporting, percentages from counts and 0–1 fractional percentages.
- Numeric colour ramps or distinct categorical colours for text fields such as ward names.
- Polygon and point overlays with visibility, drawing order, labels and legends.
- Continuous colours, equal intervals, quantiles and explicit fixed breaks.
- Configurable colours, source caption, labels and high-resolution exports.
- Appearance presets in JSON; commented scripts; synthetic demo and GitHub checks.

The Thurrock profile starts with provisional colours that can be changed in `config/councils.csv` or in the app. Reusable boundary sources are recorded in `config/boundary_sources.csv`; council-specific filters are recorded separately.

## Read next

- [Start real work locally](docs/REAL_DATA_SETUP.md): move from the demo to real boundaries and indicators.
- [Add another council](docs/COUNCIL_PROFILES.md): create a profile and download its boundaries.
- [Population indicator test data](docs/INDICATOR_TEST_DATA.md): generate ward and LSOA CSV examples.
- [User guide](docs/USER_GUIDE.md): setup, map workflow and troubleshooting.
- [Code and process guide](docs/CODE_GUIDE.md): file structure, functions and maintenance.
- [Validation checklist](docs/VALIDATION.md): checks to run before operational use.

## GitHub

Create a repository and add the contents of this folder. `.github/workflows/check-r.yml` runs R checks on pushes and pull requests. `.gitignore` excludes local input files and generated outputs; it does not protect data saved elsewhere in the project. Review files before committing. No repository has been created or published for you.

No licence has been chosen for this project's code yet. Choose one before inviting reuse. Boundary/data licences and attribution requirements are separate.
