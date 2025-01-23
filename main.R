# Imports ----

source("lse_diss/api_client.R")
#source("lse_diss/data/bulk.R")
library(dplyr)
library(tidyr)

client <- make_client()

patents_resp <- client$get_patents(
  make_params("patents", size = 1000)
)

patents <- patents_resp |>
  bind_rows() |>
  unnest_wider(inventors)

patents |>
  pull(inventor_country) |>
  unique()

patent_ids <- patents |>
  pull(patent_id) |>
  unique()

citations_resp <- client$get_related(
  "us_patent_citations",
  make_params("us_patent_citations", ids = patent_ids, size = 1000)
)

citations <- citations_resp |>
  bind_rows() |>
  filter(citation_category == "cited by applicant")
