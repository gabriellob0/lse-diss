library(dplyr)
library(tidyr)
library(lubridate)

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
    \(start) c(format(start, "%Y-%m-%d"), format(start + years(2) - days(1), "%Y-%m-%d"))
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

make_patents <- function(dates) {
  patents_resp <- client$get_patents(
    make_params("patents", dates = dates, size = 1000)
  )

  # build assignee dataset and filter
  assignees <- patents_resp |>
    map(\(x) discard_at(x, "inventors")) |>
    bind_rows() |>
    select(patent_id, assignees) |>
    unnest_wider(assignees) |>
    group_by(patent_id) |>
    filter(n() == 1, assignee_type == 2, assignee_country == "US") |>
    ungroup() |>
    mutate(patent_id, assignee_id = basename(assignee), .keep = "none")

  # build patent dataset join to assignee
  patents_resp |> # TODO: test for matching size
    map(\(x) discard_at(x, "assignees")) |>
    bind_rows() |>
    hoist(inventors, "inventor") |>
    select(-inventors) |>
    right_join(assignees, by = join_by(patent_id)) |>
    distinct()
}
