library(fs)
library(arrow)
library(dplyr)
library(purrr)
library(tibble)


calculate_density <- function(distances, range) {
  reflected_distances <- c(distances, -distances)

  # NOTE: most papers use the default bandwidth here, Silverman's
  # TODO: but it might not be recommended

  # NOTE: default is the Gaussian, which is also used by OD
  reflected_densities <- reflected_distances |>
    density(
      bw = "SJ",
      from = -range,
      to = range,
      n = 512
    ) |>
    keep_at(c("x", "y")) |>
    bind_rows() |>
    rename(distance = x, density = y)

  # NOTE: this is Silverman's reflection method
  reflected_densities |>
    mutate(density = if_else(distance >= 0, 2 * density, 0)) |>
    filter(distance >= 0)
}

# data ----
controls <- read_parquet(path("data", "processed", "controls.parquet"))
distances <- read_parquet(path("data", "processed", "distances.parquet"))

RANGE <- max(distances$distance * 1.5)

# treatment ----
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

treated_density <- treated_group |>
  pull(distance) |>
  calculate_density(distances = _, RANGE)

plot(treated_density$density)


#simulations ----
N <- 10

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
  map(\(x) calculate_density(x, RANGE)) |>
  bind_rows(.id = "iteration")


# confidence intervals
local_cis <- densities |>
  group_by(distance) |>
  summarise(
    lower_local = quantile(density, 0.05),
    upper_local = quantile(density, 0.95)
  )

global_cis
