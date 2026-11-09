# Thurrock overlay maps

Snapshot prepared 24 October 2026. All three GeoPackages are in
`data/input/map/thurrock/` and appear after **Refresh files**. Load a ward or LAD
polygon base, then choose these files in **Layers** and click **Add layer**.
Use the `name` column for optional site labels.

| GeoPackage | Contents | Source / limitations |
| --- | --- | --- |
| `thurrock_lower_thames_crossing_project_area.gpkg` | One multipart project-area polygon | [Planning Data / Planning Inspectorate](https://www.planning.data.gov.uk/entity/11100000133), OGL v3.0. This is the published project extent, not a road centreline, tunnel alignment or construction plan. The whole project extends beyond Thurrock. Use Clip to base to restrict it. |
| `thurrock_major_parks_points.gpkg` | Nine selected major park locations | [OS Open Greenspace public service](https://services.arcgis.com/qHLhLQrcvEnxjtPr/arcgis/rest/services/OS_Open_Greenspace/FeatureServer/1). A point inside each park's Thurrock portion is derived from its polygon. These are representative site locations, not visitor entrances. The service's source edition is unspecified. Contains OS data, Crown copyright and database right; OGL v3.0. |
| `thurrock_tourist_attractions_points.gpkg` | Five selected tourist/heritage destinations | A curated substitute for a comprehensive council tourism point download: named OpenStreetMap museum/viewpoint points plus two heritage forts. Coverage is selective, not a complete or ranked attractions inventory. |

Park locations: Belhus Woods Country Park, Little Belhus Country Park, Langdon
Hills Country Park, Grays Beach Riverside Park, Grays Park, Chafford Gorges Nature
Park, Mardyke Country Park, Dilkes Park and Thomas Bata Memorial Park. Names retain
the OS source spelling. This selection does not cover every council-listed park.

Attractions: Thurrock Museum, Chafford Gorges Visitor Centre, Heron Point,
Tilbury Fort and Coalhouse Fort. The first three use the
[Esri public OpenStreetMap tourism point service](https://services-eu1.arcgis.com/zci5bUiJ8olAal7N/arcgis/rest/services/OSM_EU_Tourism/FeatureServer/0)
(copyright OpenStreetMap contributors, ODbL 1.0). Tilbury Fort uses the published
[English Heritage visitor coordinate](https://www.english-heritage.org.uk/visit/places/tilbury-fort/directions/).
Coalhouse Fort uses a representative point inside the
[Historic England heritage area published by Planning Data](https://www.planning.data.gov.uk/entity/7500716)
(OGL v3.0). A point on an estate does not identify an entrance or imply access.
The mixed-source point file retains each feature's attribution and location method.

The council's linked open-data destination was unavailable and the Overpass
download endpoints failed, so the selected public OS and tourism sources above
were used. No locations were guessed.

Raw downloads remain in `data/input/*_source.geojson`. Rebuild with
`source("scripts/06_prepare_local_overlays.R")`; change its `refresh` flag to TRUE
to fetch fresh snapshots. It checks download limits/errors, geometry validity,
point membership in Thurrock, output CRS (EPSG:27700) and GeoPackage read-back.
`overlay_manifest.csv` records files, layer names and counts. Source URLs,
licences, snapshot date and location methods are also stored in the features.

Suggested export caption:
“Boundary: ONS. LTC project area: Planning Inspectorate via Planning Data (OGL).
Park locations: OS Open Greenspace (contains OS data). Attractions: OpenStreetMap
contributors (ODbL), Historic England via Planning Data, and English Heritage.
Overlay snapshot 24 October 2026; selected destinations; representative locations.”
