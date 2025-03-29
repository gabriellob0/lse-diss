library(lubridate)
library(fs)
library(arrow)
library(dplyr)
library(tidyr)

make_dates <- function(date_range) {
  start_date <- ymd(date_range[1])
  end_date <- ymd(date_range[2])

  if (interval(start_date, end_date) < years(2)) {
    return(
      list(c(format(start_date, "%Y-%m-%d"), format(end_date, "%Y-%m-%d")))
    )
  }

  # Calculate the number of complete 2-year intervals
  n_intervals <- floor(as.numeric(interval(start_date, end_date) / years(2)))

  # Generate sequence of start dates for each interval
  interval_starts <- start_date + years(seq(0, n_intervals * 2 - 2, by = 2))

  intervals <- map(
    interval_starts,
    \(start)
      c(
        format(start, "%Y-%m-%d"),
        format(start + years(2) - days(1), "%Y-%m-%d")
      )
  )

  # Handle remainder if exists
  remainder_start <- start_date + years(n_intervals * 2)

  if (remainder_start < end_date) {
    intervals <- c(
      intervals,
      list(c(format(remainder_start, "%Y-%m-%d"), format(end_date, "%Y-%m-%d")))
    )
  }

  intervals
}

make_patents <- function(
  api_client = NULL,
  dates,
  fpath = path("data", "raw", "patents")
) {
  if (!codec_is_available("zstd")) {
    stop("Change parquet compression to available type")
  }

  dir_create(fpath)
  file_name <- paste(dates, collapse = "_to_")

  get_patents <- api_client$get_patents
  make_params <- api_client$make_params

  patent_param <- make_params("patents", dates = dates, size = 100)
  patents_resp <- get_patents("patents", patent_param, max_reqs = Inf)

  # build assignee dataset and filter
  assignees <- patents_resp |>
    map(\(x) discard_at(x, "inventors")) |>
    bind_rows() |>
    unnest_wider(assignees) |>
    group_by(patent_id) |>
    filter(n() == 1, assignee_type == 2, assignee_country == "US") |>
    ungroup() |>
    select(patent_id, assignee_id, assignee_organization, assignee_location_id)

  # build patent dataset and join to assignee
  patents <- patents_resp |>
    map(\(x) discard_at(x, "assignees")) |>
    bind_rows() |>
    unnest_wider(inventors) |>
    filter(inventor_country == "US") |>
    select(
      patent_id,
      patent_date,
      patent_abstract,
      patent_earliest_application_date,
      patent_num_times_cited_by_us_patents,
      inventor_id,
      inventor_location_id,
      inventor_sequence
    ) |>
    right_join(assignees, by = join_by(patent_id)) |>
    distinct()

  write_parquet(
    patents,
    path(fpath, file_name, ext = "parquet"),
    compression = "zstd"
  )
}
