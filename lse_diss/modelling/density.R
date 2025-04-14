library(fs)
library(arrow)
library(dplyr)
library(purrr)
library(tibble)


# TODO: Following DO, we define the maximum distance as the median of all
# distances of all possible counterfactual citations

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

simulate_densities <- function(controls, distances, range, n_draws = 1000) {
  control_draws <- 1:n_draws |>
    map(
      \(i)
        controls |>
          group_by(cited_patent_id, citing_patent_id) |>
          slice_sample(n = 1) |>
          mutate(iteration = i),
      .progress = TRUE
    )

  agg_controls <- control_draws |>
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

  agg_controls |>
    deframe() |>
    map(\(x) calculate_density(x, range)) |>
    bind_rows(.id = "iteration")
}

calculate_local_bands <- function(simulated_densities) {
  local_cis <- simulated_densities |>
    group_by(distance) |>
    summarise(
      lower_local = quantile(density, 0.05),
      upper_local = quantile(density, 0.95)
    )

  density_local <- simulated_densities |>
    left_join(local_cis, by = "distance") |>
    mutate(median_density = median(density), .by = distance)

  density_local
}

calculate_global_bands <- function(local_bands) {
  global_cis <- local_bands |>
    mutate(density_deviation = density - median_density) |>
    group_by(iteration) |>
    summarise(
      max_dev = max(density_deviation),
      min_dev = min(density_deviation)
    ) |>
    summarise(
      upper_threshold = quantile(max_dev, 0.95),
      lower_threshold = quantile(min_dev, 0.05)
    )

  density_global <- local_bands |>
    bind_cols(global_cis) |>
    mutate(
      upper_band = median_density + upper_threshold,
      lower_band = median_density + lower_threshold
    ) |>
    select(distance, upper_band, lower_band) |>
    distinct()

  density_global
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

simulated_densities <- simulate_densities(controls, distances, RANGE, 10)
