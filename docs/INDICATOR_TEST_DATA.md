# Population indicator test data

Run `source("scripts/05_create_population_test_data.R")` from the project root.
It writes four map-ready CSVs to `data/input/indicator/thurrock/`: separate ward
and LSOA files for total population and estimated percentage aged 0 to 15.

The source is ONS Census 2021 TS007A. LSOA population and age-band counts are
direct official figures. Ward figures sum official OA records after assigning each
OA point-on-surface to the May 2026 ward boundary. Exact age 15 counts are not
available in TS007A at OA/LSOA level, so age 15 is estimated as one-fifth of the
published 15-19 band. Every output row records its status, source and method.

In the app, join `area_code` in the CSV to `WD26CD` for May 2026 wards or
`LSOA21CD` for 2021 LSOAs. Map `data_population_2021` for whole-number population
or `data_age_0_15_estimated_pct` for percentage. The percentage files also contain
`age_0_15_estimated_count` and `population_2021`, so the app's percentage
calculator can be tested using those as numerator and denominator.
