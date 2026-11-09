# Validation before operational use

## Main polygon boundary controls QC, 25 October 2026

Map appearance now controls the base polygon outline width (0–3 mm) and colour.
All five rendering paths (plain plus four classification methods) use those
settings; zero width removes strokes, including PDF hairlines. The fields are
included in appearance JSON, its numeric/text restore dispatch and generated R
code. Existing appearance files without the new fields remain accepted.

The full suite passed **131 expectations, zero failures, zero test warnings and
zero skips**. Checks include each rendering mode, hidden strokes, invalid widths
and colours, older settings, and the server/export/generated-code round trip.
A real ward-map PNG using 0.5 mm dark grey boundaries was exported and visually
inspected: `output/qc/main-boundary-controls.png`. These changes are saved in the
existing working directory.

## Multiple-overlay workflow QC, 25 October 2026

The existing Layers tab now accepts blank names (using the spatial layer name)
and repeated names (adding numbered suffixes). Its new count and instructions
clarify repeated additions and the effect of reloading base polygons. There is
no one-overlay limit and no additional tab or layer-slot limit was introduced.

The full suite passed **110 expectations, zero failures, zero test warnings and
zero skips**. A new server integration check adds three overlays with different
geometry/appearance, verifies preservation of earlier layers, renders/exports
them together and reproduces them from generated R code. It also checks further
additions with unchanged names, file/layer mismatch recovery, visibility and
removal without disturbing other layers.

Browser QC loaded a LAD base once and added parks (9 points), attractions
(5 points) and the LTC project area (1 multipart polygon), using the same Add
layer form and blank display names. The counter reached three visible overlays,
and all three appeared in the table with independent colours. Evidence:
`output/qc/three-layer-controls.png`. Changes were made directly in the existing
working directory; the earlier ZIP copies were not updated by this change.

## Correction QC, 24–25 October 2026

R 4.4.1 completed **90 test expectations, zero failures, zero test warnings,
zero skips**. This includes the three discrete classification methods, boundary
inclusion, decimal/suffix formatting, tied values, thin outlines independent of
point size, overlay editing, reordering, visibility/removal, generated-code
reproduction, exports and all three downloaded/derived local GeoPackages.

All new GeoPackages were reopened: 1 Lower Thames Crossing multipart project
polygon, 9 park points and 5 selected tourist/heritage points. Checks confirmed
valid nonempty geometry, EPSG:27700 and point membership in Thurrock.
Sources, substitutions and coverage limits are in `LOCAL_OVERLAYS.md`.

Browser QC loaded real wards, added both point datasets and the project polygon,
checked the relocated removal controls, moved a layer forward while retaining
selection, and removed that selected layer. Thin boundary editing is covered by
the server tests and generated-code round trip.

`scripts/07_qc_overlays.R` exported PNG/PDF/JPG examples and separate legend PNGs
for all four classifications under `output/qc/`. Visual inspection of the three
banded legends confirmed readable ranges without interval brackets; the combined
map confirmed point alignment, overlay symbols, thin outlines and source caption.
The legend examples use synthetic QC values, not real population statistics.

R reported startup locale warnings and a package-built-under-newer-R notice;
neither prevented checks or exports. The older validation record below describes
the previous environment state, not a current test blocker.

## Current evidence

On 21 October 2026, all R source files parsed with local R 4.4.1. The configured
ONS downloader completed eleven Thurrock GeoPackages in the starter profile folder
`data/input/map/thurrock/`, including the December 2019 ward layer.
Each file was reopened, checked for its expected feature count, valid geometry and
EPSG:27700 output. The Shiny application object constructed successfully.

The `testthat` suite did not start in the tool session because the installed
`testthat` needs `rlang >= 1.1.6` while that session loaded `rlang 1.1.4`. Run
`source("scripts/01_install.R")` in RStudio to update the affected dependency, then
run the suite. Browser interaction and final exported-map appearance still need a
user review at the intended report dimensions.

## Local checks

1. Install dependencies with `scripts/01_install.R`.
2. Run `Rscript tests/run_tests.R` from the project root; all tests must pass.
3. Create demo inputs and run `scripts/04_script_example.R`; inspect the PNG and PDF.
4. Launch the app and load `demo_areas`.
5. Join the demo CSV on `code`; expect four matched records and one missing count value.
6. Map `data_count`; verify zero/missing handling with your own prepared test table if needed.
7. Calculate `.map_percentage`; check area 1 = 12%, area 2 = 31.25%, area 3 missing, area 4 about 33.33%.
8. Add `demo_zone` and `demo_points`; check visibility, drawing order, labels and legends.
9. Change colours, classification and labels. Try an invalid colour and out-of-range fixed breaks; expect clear errors.
10. Export PNG, JPG and PDF at your target report size; inspect text, clipping and legends.
11. Save appearance JSON, change colours, reload it and confirm restoration.
12. Test one real boundary file for each operational council profile, a matching indicator CSV, a polygon overlay and a point overlay. Confirm source CRS, code edition, attribution and output totals.

## Decisions still needed

- Verified colours for each council profile.
- Whether future boundary releases should replace or sit alongside the configured editions.
- Whether operational Census membership must use edition-matched official lookup tables instead of the current documented spatial selection.
- The code licence before public reuse.

Only mark the implementation verified after the R checks and browser review have actually passed.
