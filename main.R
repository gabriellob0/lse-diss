# Imports ----
library(reticulate)
use_virtualenv(here::here(".venv"))

features <- import("lse_diss.features")

source("lse_diss/data/make_client.R")
source("lse_diss/data/make_data.R")

# Data ----
client <- make_client()
make_data(client)