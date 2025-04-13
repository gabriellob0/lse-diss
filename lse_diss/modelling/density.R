library(fs)
library(arrow)
library(dplyr)

controls <- read_parquet(path("data", "processed", "controls.parquet"))
distances <- read_parquet(path("data", "processed", "distances.parquet"))

distances |>
  filter(treatment_dummy == 1) |>
  pull(distance) |>
  density() |>
  plot()

# not sure about this, but I am guessing
# 1. pick the controls
# 2. join the distances

treated_group <- controls |>
  select(cited_patent_id, citing_patent_id) |>
  distinct() |>
  left_join(
    distances,
    by = c(
      "cited_patent_id" = "parent_patent_id",
      "citing_patent_id" = "child_patent_id"
    )
  ) |>
  pull(distance)

control_group <- controls |>
  group_by(cited_patent_id, citing_patent_id) |>
  slice_sample(n = 1) |>
  left_join(
    distances,
    by = c(
      "cited_patent_id" = "parent_patent_id",
      "control_patent_id" = "child_patent_id"
    )
  ) |>
  pull(distance)
