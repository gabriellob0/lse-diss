# Imports ----

source("lse_diss/data/api_client.R")
source("lse_diss/features.R")

# Data ----
client <- make_client()

make_dates(c("2005-01-01", "2005-01-02"))

patents <- make_patents(dates = c("2023-01-01", "2024-01-01"))

# build originating patent dataset
#originating <- 


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
