source("lse_diss/dataset.R")
library(dplyr)
library(tidyr)

api_fields <- c(
  "patent_id",
  "patent_date",
  "inventors"
)

patents <- get_patents(fields = api_fields)

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
