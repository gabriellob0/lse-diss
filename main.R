source("lse_diss/data/api.R")
source("lse_diss/data/bulk.R")
library(dplyr)
library(tidyr)

# TODO: figure out how to not run out of memory
get_bulk_data(readRDS("references/bulk_data_urls.Rds"))


# Calling API with functions ----------------------------------------------
api_fields <- c(
  "patent_id",
  "patent_date",
  "patent_abstract",
  "inventors"
)

# Retrieve patents
patents <- get_patents(fields = api_fields, size = 10)

patents_tidy <- bind_rows(patents$patents) |>
  unnest_wider(col = inventors) |>
  mutate(inventor_id = basename(inventor))

# Retrieve all patents
all_patents <- get_all_patents(fields = api_fields)

all_patents_tidy <- bind_rows(all_patents) |>
  unnest_wider(col = inventors) |>
  mutate(inventor_id = basename(inventor))

# Verify unique patent count
length(unique(all_patents_tidy$patent_id))

# Retrieve citing patents using new get_by_id() function
citing_patents <- get_by_id(
  ids = unique(patents_tidy$patent_id), 
  query_type = "citations"
)

citing_patents_tidy <- bind_rows(citing_patents$us_patent_citations)

# Retrieve inventors using new get_by_id() function
inventors <- get_by_id(
  ids = unique(patents_tidy$inventor_id), 
  query_type = "inventors"
)

inventors_tidy <- bind_rows(inventors$inventors) |>
  mutate(location_id = basename(inventor_lastknown_location))

# Retrieve locations using new get_by_id() function
locations <- get_by_id(
  ids = unique(inventors_tidy$location_id), 
  query_type = "locations"
)

locations_tidy <- bind_rows(locations$locations)


# Saving some data --------------------------------------------------------
patents_test <- all_patents_tidy |>
  select(patent_id, patent_abstract) |>
  distinct()

arrow::write_csv_arrow(patents_test, "data/interim/patents_test.csv")


