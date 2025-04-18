BASE_YEAR=5

# Imports ----
library(fs)
library(reticulate)

use_virtualenv(path_wd(".venv"))

source("lse_diss/data/make_client.R")
source("lse_diss/data/make_data.R")

ft <- import("lse_diss.features")
ann <- import("lse_diss.modelling.ann")

# Controls

originating <- ft$controls$make_originating(
  base_year=BASE_YEAR,
  duration_months=0,
  duration_years=5
)

treated = ft$controls$make_treated(
  originating_set,
  base_year = BASE_YEAR,
  duration = 20
)

ft$controls$save_controls(
  originating,
  treated,
  duration = 20,
  search_range = 180,
  path=Path("data", "interim", "controls_alt"),
  batch_size=500,
)

ft$abstracts$filter_embeddings()