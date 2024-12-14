source("lse_diss/dataset.R")
library(dplyr)
library(tidyr)

api_fields <- c(
  "patent_id",
  "patent_title",
  "patent_date",
  "assignees.assignee_organization",
  "assignees.assignee_type"
)

patents <- fetch_patents(fields = api_fields)

#saveRDS(patents, file = "data/raw/patents.rds")

patents_tidy <- bind_rows(patents$patents)

citations <- fetch_citations()
