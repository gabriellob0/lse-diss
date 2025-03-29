# Imports ----

source("lse_diss/data/api_client.R")
source("lse_diss/data/clean_responses.R")

# Data ----
client <- make_client()

make_dates(c("2018-01-01", "2025-01-01")) |>
  walk(\(x) make_patents(client, dates = x), .progress = TRUE)
