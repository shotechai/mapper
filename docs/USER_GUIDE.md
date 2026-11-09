# User guide

## 1. Install and launch

Use R 4.3 or newer and RStudio. Open `Mapper.Rproj` so relative paths start in the right folder. In the console:

```r
source("scripts/01_install.R")
shiny::runApp(".")
```

The app opens in a browser but runs on your computer. Stop it using RStudio's Stop button. Packages need the internet to install; ordinary mapping does not.

On Windows/macOS, install current R and use CRAN binaries if offered. If `sf` cannot install, check the error for missing GDAL, GEOS, PROJ or udunits libraries. On Ubuntu/Debian these are typically installed by an administrator with:

```bash
sudo apt-get install libudunits2-dev libgdal-dev libgeos-dev libproj-dev
```

## 2. Try fictional data first

Run `source("scripts/02_create_demo.R")` once, then launch the app or refresh its files. This creates `demo.gpkg` containing:

- `demo_areas`: four fictional polygons.
- `demo_points`: two fictional sites.
- `demo_zone`: a fictional polygon overlay.

It also creates `demo_indicators.csv`. These are teaching data, not real council boundaries or statistics. The script refuses to overwrite an existing demo file.

## 3. Load the base map

1. Select a council profile. Its default folder is `data/input/map/<council-slug>/`; you can enter another folder.
2. Click **Refresh files** and select the file and its polygon layer.
3. For an area-specific layer, leave **Use whole layer** selected.
4. For a larger layer, optionally choose an attribute. All values start selected; remove exclusions, use **Select all** to restore them, or **Clear all** to choose a subset.
5. Click **Load base polygons**.

For the demo, choose `demo.gpkg` → `demo_areas`. Set a title stating that it is fictional.

The base must contain polygons; points belong in the Layers panel. Loading another base clears previous joins and overlays. Changing a dropdown alone does not replace the loaded base.

A national layer can only be filtered to a council if it has a suitable attribute or you select the relevant constituent area codes. The app does not infer official local-authority membership. If the attribute is absent, prepare a local subset using the correct official lookup first. A filename or area name cannot establish the boundary edition.

## 4. Add an indicator CSV

In **Data**, choose a CSV. It should have one row per area, for example:

| ward_code | count | numerator | denominator |
|---|---:|---:|---:|
| EXAMPLE001 | 12 | 12 | 100 |
| EXAMPLE002 | 25 | 25 | 80 |

These codes are illustrative. Actual codes must match your selected boundary edition.

Choose the code column in the boundaries and in the CSV, then click **Join data**. Review:

- **Matched:** boundary areas found in the CSV.
- **Without data:** selected areas without a CSV record.
- **Unused data:** CSV records outside the selected boundaries.

Duplicate or blank codes stop the join. CSV columns receive a `data_` prefix, so `count` becomes `data_count`. CSV fields are read as text to preserve geography codes; numeric indicators are converted when mapped. Use plain numbers without comma separators, `%` signs or suppression text. Blank and `NA` values remain missing; zero remains zero.

A matched row can still have a missing indicator: the join checks count record matches, not complete values. Inspect the attributes and map as well.

Choose the joined indicator from **Indicator column** in the sidebar. For the demo, join `code` to `code` and select `data_count`. Set **Colour selected column as** to **Numeric values** for measures or **Categories** for text such as ward names. Categorical colouring assigns a preset colour to every unique value and lists those values in the legend. To customise them, edit the six-digit hex code beside each category and click **Apply category colours**. Use **Reset preset colours** to restore the automatic palette.

For real-data testing, run `source("scripts/05_create_population_test_data.R")`.
This creates separate Thurrock ward and LSOA population and age-percentage CSVs
under `data/input/indicator/thurrock/`. See `docs/INDICATOR_TEST_DATA.md` for the
join columns, source and estimation method.

### Percentages

Select numerator and denominator columns and click **Calculate percentage**. Select `.map_percentage` as the indicator. It is calculated as `100 × numerator / denominator`; a missing or zero denominator produces missing data. Negative counts or numerator greater than denominator are rejected.

If the CSV already holds percentages, map that column directly and choose its **Indicator value scale**. Use **Values as entered** for `20` meaning 20%; use **Fractional percentage** for `0.2` meaning 20%. Fractional percentages must be between 0 and 1 and are converted to a 0–100 mapping scale; `%` is added automatically when the suffix is blank. Decimal values such as `20.5` are accepted. Do not average percentages to aggregate areas; combine their counts and recalculate.

## 5. Style the base map

- **Plain boundary map:** choose this when no indicator is needed.
- **Continuous:** smooth ramp from low to high.
- **Equal intervals:** equal numerical widths.
- **Quantiles:** approximately equal numbers of areas; ties can reduce the number of bands.
- **Fixed breaks:** enter increasing limits such as `0,20,40,60,80,100`. They must cover all values.

Use the same fixed breaks and colours for comparable maps. Band legends display numeric ranges; put units in the legend title. The numeric suffix and decimal setting format continuous legends and numeric base labels.

Colours use six-digit hex codes. Starting colours come from the selected profile in `config/councils.csv`; they can be changed in the app for one map. Missing areas use a separate grey by default; explain it in the caption when missing values are present.

Use **Label text colour** and **Label font** for base and overlay labels; **Legend text colour** and **Legend font** apply to both legend titles and entries. Portable font choices are sans serif, serif and monospace.

The Map tab starts with a 900-pixel preview. Choose another **Height** from the compact toolbar at the right of the tab menu. Click **Expand canvas** to hide the control pane and use the full browser width; the button changes to **Show controls** so you can restore the pane. **+ Zoom**, **− Zoom**, the arrow buttons and **Fit** change the geographic view used in preview, export and R code. An arrow moves the map content in the direction it points. Height and the expanded view only affect the screen. Loading a new base resets the geographic view.

Choose **Title alignment** to place the title at the left, middle or right of the map. Select **Show map canvas boundary** when you want a visible outline around the geographic plotting area; the outline also makes zooming and panning limits easier to see. Both settings are retained in saved appearance JSON and generated R code.

Turn on labels and select an attribute. Overlapping labels may be omitted to improve readability. At OA/LSOA level, use labels sparingly. Base labels draw above overlays.

## 6. Add polygons and points

In **Layers**, select a GeoPackage and layer, give it a unique display name, and choose its colour, opacity, size and optional label. Point symbols can be circles, triangles or squares. For polygons, size controls outline width; select **Polygon outline only** for an unfilled boundary.

Choose how to restrict the overlay:

| Option | Result |
|---|---|
| Full layer | Keep all features; map view remains focused on the base |
| Intersecting features | Keep whole features touching/intersecting the base |
| Clip to base | Cut geometry at the base boundary |

Click **Add layer**. Add as many layers as needed. Last row draws on top. Select a row to show/hide, remove or move it. Use **Assign colour ramp to all overlays** to distribute colours across the stack in drawing order, including hidden layers. This resets layers to single-colour styling. Then select a layer, edit its colour and click **Apply layer colours**.

To colour features within an overlay, select its numeric column under **Colour areas / points by numeric value**, choose low/high ramp colours and click **Apply layer colours**. The app uses five equal-interval bands (fewer for constant values), fills polygons even if added as outline only, and uses the missing-data colour for missing values. Each visible numeric overlay has labelled bands in the Layers legend, including exports. Select **Single layer colour** to return to uniform styling. Base indicator ramps remain controlled in the sidebar.

For the demo, add `demo_zone`, then `demo_points`. Add points last so filled polygons do not cover them. These controls display features; they do not count points within areas or allocate data between boundaries.

## 7. Export and reuse appearance

In **Export & settings**, choose PNG, PDF or JPG. Set width/height in inches and DPI, then download. PNG is suitable for reports; PDF retains vector detail; JPG can soften text and lines. The default is 10 × 8 inches at 300 DPI. Maximum dimensions are 30 inches per side and 600 DPI.

Preview and export share a plotting function. Different output dimensions can change label placement and text wrapping. Check the downloaded file before publishing.

**Save appearance JSON** records colours, classification, title, column names and layout. It does not save data, selections, joins or overlays. To reuse it: reload the base, repeat the join and overlays, then load the JSON. Column names must exist in the current data. Closing the app clears the session's loaded data and layers.

### Reproduce the map with R

The **R code** tab displays the code for the loaded map and offers **Download R script**. Run it from the `thurrock-mapper` project directory. It loads the recorded boundary files, reapplies the loaded base selection, embeds the uploaded CSV used in the join, repeats percentage calculations and recreates overlay order, colours, labels, fonts and geographic view. Changing a candidate file or filter without loading it does not change the recorded base.

The script prints the map and exports `area-map` in the selected format using the export dimensions. Existing exports at that path are replaced when the script runs. It requires this project's `R/` helpers and the recorded boundary files; it is not a standalone copy of the source boundaries. CSV values are included in the script, so treat it as containing the joined data when sharing it.

## 8. Boundary download

Run the configured R downloader from the project root:

```r
source("scripts/03_download_boundaries.R")
```

It queries official ONS ArcGIS FeatureServer layers, handles service record limits,
selects the configured council and writes GeoPackages to its profile folder: LA
boundaries for May 2026 and May 2025; ward boundaries for May 2026, May 2025 and
December 2019; plus OA, LSOA and MSOA boundaries for the
2021 and 2011 Census editions. A manifest CSV records sources and feature counts.

Existing files are retained by default, allowing an interrupted download to resume.
To refresh every file deliberately:

```r
source("R/load.R")
manifest <- download_boundary_catalogue(overwrite = TRUE)
```

The older `download_boundaries()` helper remains available for a direct GeoPackage
or ZIP URL. The configured bulk downloader uses `download_arcgis_boundaries()`.
See `docs/COUNCIL_PROFILES.md` before adding another council.

## Common problems

| Problem | Action |
|---|---|
| No files listed | Check the folder path, add `.gpkg` files and refresh; subfolders under the selected folder are searched |
| No CRS | Assign the correct CRS using the source information before loading |
| Unsupported geometry | Supply a point or polygon layer; line/geometry-collection layers are not supported |
| Join fails | Check duplicates, blanks, code columns and geography editions |
| Indicator is not numeric | Remove formatting/suppression text in your analytical preparation step |
| Empty or hidden overlay | Check selection mode, CRS, opacity and drawing order |
| Map is slow | Use a local subset or an appropriate simplified boundary file |
| Settings appear incomplete | JSON saves appearance only; repeat data loading and layer setup |

Record data sources, boundary edition and required attribution in the map caption. This app is intended initially for trusted local use; a shared deployment needs authentication and controlled file access.
# October 2026 corrections

The main **Map appearance** section now includes **Polygon boundary thickness
(mm)** and **Polygon boundary colour (hex)** below Base opacity. These apply to
the main map in plain, continuous and banded modes. Thickness ranges from 0 to
3 mm; 0 hides the boundaries. Defaults are 0.25 mm and white (`#FFFFFF`). Changes
apply immediately to the preview and exports and are included in appearance JSON
and generated R code. Overlay boundary controls remain independent.

## Add several overlays to the same map

Keep using the existing **Layers** tab. There is no fixed limit of one overlay,
and no additional tab is needed.

1. Load your base polygons once.
2. In **Layers**, select the first overlay GeoPackage and layer, choose its
   appearance, and click **Add layer**.
3. Select the next GeoPackage/layer in the same form and click **Add layer** again.
   Repeat for the third overlay and any further overlays. Earlier additions remain.
4. Check the count at the top and the table below. Use different colours/symbols
   and the existing visibility/order controls when features overlap.

The display name is optional: leaving it blank uses the selected spatial layer's
name. Repeated names receive `(2)`, `(3)` and so on automatically, so forgetting
to rename a layer no longer blocks the next addition. Each added layer captures
its own geometry and appearance; changing the add form prepares the next overlay.
Use **Layer to change** for edits/removal. All visible overlays appear together
in the main map and exports, and all additions appear in generated R code.

Do not click **Load base polygons** between additions: reloading the base clears
the joins and overlays. Changing council profile also clears loaded layers.

Three additional local overlay maps are available: Lower Thames Crossing project
area, nine major park points and five selected tourist/heritage points. See
[sources and coverage](LOCAL_OVERLAYS.md). Click **Refresh files** to discover them.

Discrete legends now show ranges such as `0.0% to 10.0%` and
`> 10.0% to 20.0%`. The first band includes its lower bound; later bands exclude
their lower bound and include their upper bound. Decimal places and the numeric
suffix apply to the base legend. Extra precision is used when rounding would
make different boundaries look identical. Overlay value legends use the decimal
setting but omit the base suffix because overlays can measure different things.

**Point size** and **Polygon boundary thickness (mm)** are separate. The default
outline is 0.25 mm. After adding a polygon, select it below **Add layer**, change
**Selected polygon boundary thickness**, then click **Apply boundary thickness**.
Zero hides the outline. This setting is included in generated R code and exports.

**Remove selected layer** is below **Add layer** and the layer selector.
**Show / hide** temporarily changes visibility without removing a layer.
**Send backward** (formerly Move lower) moves a layer behind one overlay;
**Bring forward** (formerly Move higher) moves it above one overlay. They control
which overlapping features obscure others; they do not move features geographically.
The last table row draws on top. The selected layer stays selected after a move.
The base remains underneath the overlays. The colour-ramp button assigns one
colour per overlay in drawing order; the individual-layer value ramp colours
features within a selected layer using that layer's numeric column.

