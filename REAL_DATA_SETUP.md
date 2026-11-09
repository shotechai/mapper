# Start real work locally

The demo and real maps use the same app. There is no production mode to enable.
The supplied inputs are fictional; you must provide real geography and indicator data.

## 1. Continue in the RStudio session where the demo works

Open `Mapper.Rproj` inside the project folder. In the R console:

```r
getwd()                    # Must be the folder containing Mapper.Rproj
R.version.string
.libPaths()                # Useful if a different R session cannot find packages
source("tests/run_tests.R")
shiny::runApp(".")
```

If packages are missing in that session, run `source("scripts/01_install.R")`.
You do not need to recreate the demo or reinstall packages every time.
Paths entered in the app refer to this computer when R runs locally. Cloud files
must be copied here, or replaced with accessible local paths.

## 2. Choose the geography before obtaining boundaries

Start with one indicator and one geography: wards, MSOAs, LSOAs, OAs, or the whole
local authority. Record the boundary edition used by the indicator. A statistic's
reporting year does not necessarily identify its boundary edition.

Obtain an official boundary file and its source/licence information. For this app,
use a GeoPackage (`.gpkg`) containing polygons with a unique geography-code column
and a defined coordinate reference system. The app transforms coordinates into
British National Grid (EPSG:27700).

Use boundaries already restricted to the selected council for the easiest first map. If using
a wider dataset, the app can filter an existing attribute by exact values. If it
does not contain local-authority membership, prepare the subset using an official,
edition-matched lookup first. Spatial intersection alone does not establish that
an area officially belongs to the council.

Put the GeoPackage in `data/input/map/<council-slug>/`, for example
`example-council_lsoa_<edition>.gpkg`. The app searches subfolders under `data/input`.
Alternatively, enter another local folder in the app. Avoid modifying the original source file.

Other formats need preparation: the app does not directly load shapefiles,
GeoJSON, Excel workbooks, or a CSV of point coordinates. Convert spatial files to
GeoPackage using an appropriate GIS/R workflow. Point coordinates need their
correct source CRS before conversion.

## 3. Prepare one indicator CSV

Use one row per boundary area, with a geography-code column and numeric indicator
columns. Take actual codes from the matching geography; do not substitute names.
For example, the column structure could be:

```csv
area_code,count,numerator,denominator
```

Populate rows with your real codes and values. Keep codes as text. Use plain
numbers without thousands separators or percent signs. Blank/NA means missing;
zero means a real zero. Resolve suppression symbols in an explicit preparation
step without treating suppressed values as zero. Filter or aggregate repeated
area records before joining. Save the file as CSV, not XLSX.

You only need numerator/denominator columns if calculating percentages in the app.
For an existing percentage on a 0–100 scale, map it directly and use `%` as the
suffix. The suffix does not convert proportions on a 0–1 scale.

## 4. Make the first real map

1. Launch the app, select the council profile, click **Refresh files**, then select your GeoPackage and polygon layer.
2. Use **Use whole layer** for an already prepared council subset; otherwise apply
   the appropriate attribute filter. Click **Load base polygons**.
3. Open **Data**, choose your CSV, and select the geography-code column from each
   input. Click **Join data**.
4. Review **Join checks**. For a complete council-only table, all selected areas
   should match, with no unused rows. Investigate any exceptions. A matched row
   can still have a missing indicator value.
5. Select the joined **Indicator column** in the sidebar. Added CSV fields have
   a `data_` prefix: `count` becomes `data_count`.
6. Set the title, legend and colours. Record boundary edition, indicator source,
   reporting period and required attribution in the caption. Explain missing areas.
7. Add optional GeoPackage point/polygon overlays through **Layers**. Add points
   above filled polygons. These layers display features; they do not calculate
   counts of points per area.
8. Export a PNG or PDF and inspect it at the intended report size.

Use fixed breaks when comparing maps that need identical numerical bands.
The default green is provisional and can be changed in the app or `R/config.R`.

## 5. Download the complete boundary set with R

The supplied catalogue contains official ONS FeatureServer URLs for the latest two
available editions: May 2026 and May 2025 for local authorities; May 2026,
May 2025 and December 2019 for wards; and December 2021 and December 2011 for
Census OA/LSOA/MSOA geographies.

From the project root, run:

```r
source("scripts/03_download_boundaries.R")
```

This downloads eleven GeoPackages for the default Thurrock starter profile into
`data/input/map/thurrock/` and writes
`boundary_manifest.csv` with the source, edition, layer name and feature count.
Existing files are kept so an interrupted run can be resumed. To deliberately
replace all files, run `download_boundary_catalogue(overwrite = TRUE)` after
`source("R/load.R")`.

The source catalogue can be edited for a later release. Council names and colours
live in `config/councils.csv`; edition-specific LA and ward filters live in
`config/council_source_filters.csv`. See `docs/COUNCIL_PROFILES.md` to add another
council. Census layers are spatially selected using the configured council LA
boundary because their feature services do not all carry a current LA code.

## 6. Keep work repeatable

Appearance JSON saves styling only. Closing the app loses loaded selections,
joins and overlays; these must be repeated. For regular outputs, copy
`scripts/04_script_example.R` to a separate script and replace its demo filenames,
layer names, join keys, indicator, overlays, source caption and output filenames.
The supplied example always uses fictional inputs until you change those values.

Keep a short record of every input's source, boundary edition, download date,
geography-code column, indicator definition and preparation steps. Retain the
original inputs. Once the workflow and tests pass in your RStudio environment,
consider recording package versions with renv; there is currently no lockfile.

The Git ignore rules exclude `data/input/` contents and `outputs/`, but other
locations require separate review. This project is inside OneDrive: local R
execution does not stop OneDrive syncing files. Store work data in a location
appropriate for that data and point the app at it.

## Local review on 21 October 2026

All app/helper/script R files parsed successfully using installed R 4.4.1.
Functional tests could not start in the tool session because required packages
were not visible in its sandbox-specific R library. This does not establish that
packages are missing from the user's working RStudio session. Run the checks
there and complete `VALIDATION.md` with real inputs before operational use.
