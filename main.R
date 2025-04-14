# Configuration ----
# NOTE: originating patent are selected from first month of base year
BASE_YEAR = 2005

# NOTE: citing and control patents are select from the duration in year
# starting from the base year
DURATION = 5

# NOTE: how many days apart should an acceptable control be within
SEARCH_RANGE = 180

# Imports ----
library(fs)
library(reticulate)

use_virtualenv(path_wd(".venv"))

source("lse_diss/data/make_client.R")
source("lse_diss/data/make_data.R")

ft <- import("lse_diss.features")

# Data ----
if (dir_exists(path("data", "raw", "patents"))) {
  print("raw data path exists, not fetching api data")
} else {
  print("fetching api data")
  client <- make_client()
  make_data(client)
}

if (dir_exists(path("data", "raw", "bulk_downloads"))) {
  print("raw data path exists, not downloading bulk data")
} else {
  print("downloading bulk data")
  py_run_file(
    path("lse_diss", "data", "bulk_data.py"),
    convert = FALSE
  )
}

# Features ----

if (file_exists(path("data", "interim", "abstracts.parquet"))) {
  print("abstracts exists, not running features")
} else {
  # 1. patents
  ft$patents$load_patents() |>
    ft$patents$trim_abstracts() |>
    ft$patents$save_patents()

  ft$patents$filter_citations()

  # 2. controls
  agg_patents = ft$controls$make_originating(base_year = BASE_YEAR)
  treated_pairs = ft$controls$make_treated(
    agg_patents,
    base_year = BASE_YEAR,
    duration = DURATION
  )

  ft$controls$save_controls(
    agg_patents,
    treated_pairs,
    duration = DURATION,
    search_range = SEARCH_RANGE
  )

  # 3. abstracts
  ft$abstracts$filter_abstracts()
}

# Modelling ----

if (dir_exists(path("data", "processed", "embeddings"))) {
  print("embeddings exists, not encoding abstracts")
} else {
  py_run_file(
    path("lse_diss", "modelling", "embeddings.py"),
    convert = FALSE
  )
}

if (!dir_exists(path("data", "processed", "embeddings"))) {
  print("no embeddings")
  stop()
} else if (file_exists(path("data", "processed", "controls.parquet"))) {
  print("NNs exist")
} else {
  print("matching abstracts")
  py_run_file(
    path("lse_diss", "modelling", "ann.py"),
    convert = FALSE
  )
}

ft$locations$make_locations()
ft$locations$make_distances()
