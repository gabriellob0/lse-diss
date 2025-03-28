# PatentSearch API Client ----

library(httr2)
library(purrr)
library(rlang)
library(yaml)

make_client <- function(
  api_key = Sys.getenv("PATENTSVIEW_API_KEY"),
  config_path = "references/config.yaml"
) {
  if (identical(api_key, "")) {
    stop(
      "No API key found, please create PATENTSVIEW_API_KEY environmental variable"
    )
  }

  config <- read_yaml(config_path)

  endpoints <- pluck(config, "endpoints")

  make_params <- function(
    type = c("patents", "us_patent_citations", "inventors", "locations"),
    ids = NULL,
    dates = c("2023-01-01", "2024-01-01"),
    size = 5
  ) {
    type <- arg_match(type)

    params <- pluck(config, "parameters", type)

    pluck(params, "o", "size") <- size

    if (type == "patents") {
      pluck(params, "q", "_and", 1, "_gte", "patent_date") <- dates[[1]]
      pluck(params, "q", "_and", 2, "_lte", "patent_date") <- dates[[2]]
    } else {
      pluck(params, "q", 1) <- ids
    }

    params
  }

  make_req <- function(endpoint, params) {
    request("https://search.patentsview.org") |>
      req_url_path("api", "v1", endpoint) |>
      req_headers("X-Api-Key" = api_key) |>
      req_throttle(45 / 60) |>
      req_retry() |>
      req_body_json(compact(params))
  }

  next_req <- function(resp, req) {
    data <- resp |>
      resp_body_json()

    if (length(data) == 0) {
      return(NULL)
    }

    total_hits <- pluck(data, "total_hits")
    #Sys.sleep(5) # throttle stopped working, so I added this

    signal_total_pages(ceiling(total_hits / 1000))

    id_field <- names(pluck(req, "body", "data", "s", 1))

    # NOTE: This is the cursor
    pluck(req, "body", "data", "o", "after") <- pluck(data, -1, -1, id_field)

    req
  }

  get_patents <- function(
    type = c("patents", "us_patent_citations", "inventors", "locations"),
    params,
    max_reqs
  ) {
    type <- arg_match(type)

    first_req <- make_req(endpoints[[type]], params)

    resps <- req_perform_iterative(
      first_req,
      next_req,
      max_reqs = max_reqs,
      progress = TRUE
    )

    resps_successes(resps) |>
      resps_data(\(resp) resp_body_json(resp)[[type]])
  }

  list(get_patents = get_patents, make_params = make_params)
}

## Tests ----

# source("lse_diss/data/api_client.R")
#
# library(dplyr)
# library(tidyr)
#
# client <- make_client()
# get_patents <- client$get_patents
# make_params <- client$make_params
#
# patent_param <- make_params("patents", dates = c("2021-01-01", "2022-01-01"))
# patents <- get_patents("patents", patent_param, max_reqs = 7)
#
# patents_df <- patents |>
#   map(\(x) discard_at(x, "assignees")) |>
#   bind_rows()
#
# inventor_ids <- patents_df |>
#   hoist("inventors", "inventor_id") |>
#   pull(inventor_id) |>
#   unique()
#
# inventor_params <- make_params("inventors", size = 10, ids = inventor_ids)
#
# inventors <- get_patents("inventors", inventor_params, max_reqs = 7)
#
# location_ids <- inventors |>
#   bind_rows() |>
#   mutate(location_id = basename(inventor_lastknown_location)) |>
#   pull(location_id) |>
#   unique()
#
# location_params <- make_params("locations", ids = location_ids, size = 3)
#
# locations <- get_patents("locations", location_params, max_reqs = 7)
#
# patent_ids <- patents_df |>
#   pull(patent_id) |>
#   unique()
#
# citations_params <- make_params("us_patent_citations", ids = patent_ids, size = 3)
#
# citations <- get_patents("us_patent_citations", citations_params, max_reqs = 3)
#
# final_df <- inventors |>
#   bind_rows() |>
#   right_join(
#     patents_df |> hoist("inventors", "inventor_id"),
#     by = join_by(inventor_id)
#   ) |>
#   mutate(location_id = basename(inventor_lastknown_location)) |>
#   left_join(
#     locations |> bind_rows(),
#     by = join_by(location_id)
#   ) |>
#   select(inventor_id, patent_id, location_id, patent_date, patent_abstract, location_latitude, location_longitude) |>
#   filter(if_all(everything(), \(x) !is.na(x)))
