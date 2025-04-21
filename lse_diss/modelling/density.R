library(fs)
library(arrow)
library(dplyr)
library(purrr)
library(tidyr)
library(tibble)


load_data <- function(processed_path = path("data", "processed")
) {
  processed_path <- path("data", "processed")
  distances_path <- path(processed_path, "distances.parquet")
  classes_path <- path(processed_path, "classes.parquet")
  
  distances <- read_parquet(distances_path)
  
  classes <- classes_path |>
    read_parquet() |>
    filter(cited_dummy==1) |>
    select(-cited_dummy) |>
    mutate(V="All") |> 
    pivot_longer(c(cpc_section, V), values_to = "cpc_section") |>
    select(-name)
  
  median_distance <- median(distances$distance)
  
  nested_distances <- distances |>
    filter(distance<=median_distance) |>
    left_join(classes, by=join_by(parent_patent_id==patent_id)) |> 
    nest(.by=cpc_section, .key="distances")
  
  controls <- path(processed_path, "controls.parquet") |>
    read_parquet() |>
    left_join(
      distances,
      by=join_by(
        cited_patent_id==parent_patent_id,
        citing_patent_id==child_patent_id
      )
    ) |>
    left_join(
      distances,
      by=join_by(
        cited_patent_id==parent_patent_id,
        control_patent_id==child_patent_id
      )
    )
  
  nested_controls <- controls|> 
    rename(treatment=distance.x, control=distance.y) |>
    filter(treatment <= median_distance, control <= median_distance) |>
    left_join(classes, by=join_by(cited_patent_id==patent_id)) |> 
    select(-treatment, -control) |> 
    nest(.by=cpc_section, .key="controls")
  
  nested_df <- nested_distances |> 
    left_join(nested_controls, by = join_by(cpc_section)) |>
    filter(cpc_section!="D")
}

create_bands <- function(controls, distances) {

  RANGE <- max(distances$distance * 1.1)

  # TODO: Following DO, we define the maximum distance as the median of all
  # distances of all possible counterfactual citations

  calculate_density <- function(distances, range) {
    reflected_distances <- c(distances, -distances)

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

  simulated_densities <- simulate_densities(controls, distances, RANGE, 1000)
  local_bands <- calculate_local_bands(simulated_densities)
  global_bands <- calculate_global_bands(local_bands)

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
    calculate_density(distances = _, RANGE) |>
    left_join(global_bands, by = "distance") |>
    left_join(
      local_bands |>
        select(distance, lower_local, upper_local) |>
        distinct(),
      by = "distance"
    )

  treated_density
}
