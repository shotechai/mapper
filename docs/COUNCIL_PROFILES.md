# Add another council

The mapper keeps reusable boundary services separate from council-specific
configuration. Do not copy the application or edit R functions for each council.

## 1. Add a council profile

Add one row to `config/councils.csv`:

```csv
council_id,council_name,slug,primary_colour,light_colour
example-council,Example Council,example-council,#005EB8,#EAF3FA
```

`council_id` and `slug` must be unique and use lowercase letters, numbers or
hyphens. Colours must be six-digit hex values. The slug becomes the folder and
filename prefix under `data/input/map/`.

## 2. Add edition-specific filters

For every row in `config/boundary_sources.csv` whose `selection_method` is
`attribute`, add one exact filter to `config/council_source_filters.csv`. The
current catalogue requires four rows:

```csv
council_id,source_id,where
example-council,lad_2026,LAD26CD='E00000000'
example-council,lad_2025,LAD25CD='E00000000'
example-council,wards_2026,LAD26CD='E00000000'
example-council,wards_2025,LAD25CD='E00000000'
```

Replace the example values with the official LAD code for each edition. Codes can
change after local-government reorganisation, so verify both years rather than
assuming they are identical.

## 3. Download the profile

From the project root:

```r
source("R/load.R")
manifest <- download_boundary_catalogue("example-council")
readr::write_csv(
  manifest,
  file.path(council_map_dir("example-council"), "boundary_manifest.csv")
)
```

The function creates `data/input/map/example-council/`, downloads every configured
edition, and returns source and feature-count metadata. Existing files are retained
unless `overwrite = TRUE` is supplied.

To update every profile already listed in `config/councils.csv`:

```r
source("R/load.R")
all_manifests <- download_all_councils()
```

## 4. Use it in the app

Restart the app after changing profile configuration. Choose the council from the
**Council profile** list. The app switches to that profile's folder, title and
colours and clears previously loaded data and overlays to prevent councils being
mixed accidentally.

## Census geography limitation

OA, LSOA and MSOA service layers do not all include a current LAD code. The current
downloader spatially selects them using the profile's latest downloaded LAD
boundary. This is practical for councils whose boundary is stable. For a council
affected by boundary changes, verify the results against an official lookup for
the relevant Census edition before operational use. The source catalogue records
this selection method explicitly.
