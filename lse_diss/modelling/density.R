library(fs)
library(arrow)
library(dplyr)
library(purrr)
library(tibble)

controls <- read_parquet(path("data", "processed", "controls.parquet"))
distances <- read_parquet(path("data", "processed", "distances.parquet"))

treated_group <- controls |>
  select(cited_patent_id, citing_patent_id) |>
  distinct() |>
  left_join(
    distances,
    by = c(
      "cited_patent_id" = "parent_patent_id",
      "citing_patent_id" = "child_patent_id"
    )
  )

actual_density <- treated_group |>
  pull(distance) |>
  density(from = 0, to = 11000) |>
  keep_at(c("x", "y")) |>
  bind_rows() |>
  rename(distance = x, density = y)

N <- 1000

control_group <- 1:N |>
  map(
    \(i)
      controls |>
        group_by(cited_patent_id, citing_patent_id) |>
        slice_sample(n = 1) |>
        mutate(iteration = i)
  ) |>
  bind_rows() |>
  left_join(
    distances,
    by = c(
      "cited_patent_id" = "parent_patent_id",
      "control_patent_id" = "child_patent_id"
    )
  ) |>
  group_by(iteration) |>
  summarise(distances = list(distance))

densities <- control_group |>
  deframe() |>
  # TODO: figure out the density defaults
  map(\(x) density(x, from = 0, to = 11000)) |>
  list_transpose() |>
  keep_at(c("x", "y")) |>
  list_transpose() |>
  enframe() |>
  unnest_wider("value") |>
  unnest_longer(c("x", "y")) |>
  rename(iteration = name, distance = x, density = y)

quantiles <- densities |>
  group_by(distance) |>
  summarise(
    lower_local = quantile(density, 0.025),
    upper_local = quantile(density, 0.975)
  )

deviations <- densities |>
  mutate(mean = mean(density), .by = distance) |>
  group_by(iteration) |>
  summarize(
    max_pos_dev = max(density - mean), # Maximum positive deviation
    max_neg_dev = max(mean - density) # Maximum negative deviation
  ) |>
  summarise(
    global_upper_dev = quantile(max_pos_dev, 0.95),
    global_lower_dev = quantile(max_neg_dev, 0.95)
  )
