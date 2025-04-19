library(fs)
library(duckplyr)
library(gt)
library(ggplot2)

interim_patents <- read_parquet_duckdb((path("data", "interim", "patents", "*")))
interim_controls <- read_parquet_duckdb((path("data", "interim", "controls", "*")))
processed_controls <- read_parquet_duckdb((path("data", "processed", "controls.parquet")))

# Figure 1 ----
interim_patents |>
  summarise(row_count = n(),
            patent_count = n_distinct(patent_id),
            inventor_count = n_distinct(inventor_id)
  ) |>
  collect()


colnames(interim_controls)

interim_controls_counts <- interim_controls |>
  summarise(
    count = n(), #214886441
    citing_count = n_distinct(citing_patent_id), #2758
    cited_count = n_distinct(cited_patent_id), #1199
    control_count = n_distinct(control_patent_id) #306966
  ) |>
  collect() |>
  mutate(stage="pre")


processed_controls_counts <- processed_controls |>
  summarise(
    count = n(),
    citing_count = n_distinct(citing_patent_id),
    cited_count = n_distinct(cited_patent_id),
    control_count = n_distinct(control_patent_id)
  ) |>
  collect() |>
  mutate(stage="post")

figure1 <- bind_rows(interim_controls_counts, processed_controls_counts)
