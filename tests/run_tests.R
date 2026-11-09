# Run from project root: Rscript tests/run_tests.R
# Load helpers once and run tests as a script-based project, not an R package.
source("R/load.R")
if (!requireNamespace("testthat", quietly = TRUE)) stop("Install testthat first.")
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)
