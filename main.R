source("lse_diss/dataset.R")
library(dplyr)
library(tidyr)
library(arrow)

# Calling API with functions ----------------------------------------------
api_fields <- c(
  "patent_id",
  "patent_date",
  "patent_abstract",
  "inventors"
)

patents <- get_patents(fields = api_fields, start_date = "2022-01-01", size = 1000)

patents_tidy <- bind_rows(patents$patents) |>
  unnest_wider(col = inventors) |>
  mutate(inventor_id = basename(inventor))

citing_patents <- get_citing_patents(unique(patents_tidy$patent_id))

citing_patents_tidy <- bind_rows(citing_patents$us_patent_citations)

inventors <- get_inventors(inventors = unique(patents_tidy$inventor_id))

inventors_tidy <- bind_rows(inventors$inventors) |>
  mutate(location_id = basename(inventor_lastknown_location))

locations <- get_locations(inventors_tidy$location_id)

locations_tidy <- bind_rows(locations$locations)



# Saving some data --------------------------------------------------------
patents_test <- patents_tidy |>
  select(patent_id, patent_abstract) |>
  distinct()

write_csv_arrow(patents_test, "data/interim/patents_test.csv")
