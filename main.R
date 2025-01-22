source("lse_diss/api_client.R")
#source("lse_diss/data/bulk.R")
library(dplyr)
library(tidyr)

# TODO: figure out how to not run out of memory
#get_bulk_data(readRDS("references/bulk_data_urls.Rds"))

client <- make_client()
get_patents <- client$get_patents
get_related <- client$get_related
patent_params <- make_params("patents", size = 5)

patents <- get_patents(patent_params, n_requests = 7)

inventor_ids <- patents |>
  bind_rows() |>
  unnest_wider(inventors) |>
  mutate(inventor_id = basename(inventor)) |>
  pull(inventor_id) |>
  unique()

inventor_params <- make_params("inventors", ids = inventor_ids, size = 3)

inventors <- get_related("inventors", inventor_params, n_requests = 3)

location_ids <- inventors |>
  bind_rows() |>
  mutate(location_id = basename(inventor_lastknown_location)) |>
  pull(location_id) |>
  unique()

location_params <- make_params("locations", ids = location_ids, size = 3)

locations <- get_related("locations", location_params, n_requests = 3)

patent_ids <- patents |>
  bind_rows() |>
  pull(patent_id) |>
  unique()

citations_params <- make_params("us_patent_citations", ids = patent_ids, size = 3)

citations <- get_related("us_patent_citations", citations_params, n_requests = 3)
