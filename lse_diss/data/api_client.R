# PatentSearch API Client ----

library(httr2)
library(purrr)
library(rlang)

make_client <- function(api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  if (identical(api_key, "")) {
    stop("No API key found, please create PATENTSVIEW_API_KEY environmental variable")
  }

  ENDPOINTS <- list(
    patents = "patent",
    us_patent_citations = "patent/us_patent_citation/",
    inventors = "inventor",
    locations = "location"
  )

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
    Sys.sleep(5) # throttle stopped working, so I added this

    signal_total_pages(ceiling(total_hits / 1000))

    id_field <- names(pluck(req, "body", "data", "s", 1))

    # NOTE: This is the cursor
    pluck(req, "body", "data", "o", "after") <- pluck(data, -1, -1, id_field)

    req
  }

  get_patents <- function(
      type = c("patents", "us_patent_citations", "inventors", "locations"),
      params, max_reqs) {
    type <- arg_match(type)

    first_req <- make_req(ENDPOINTS[[type]], params)

    resps <- req_perform_iterative(
      first_req,
      next_req,
      max_reqs = max_reqs,
      progress = TRUE
    )

    resps_successes(resps) |>
      resps_data(\(resp) resp_body_json(resp)[[type]])
  }

  list(get_patents = get_patents)
}


make_params <- function(
    mode = c("default", "production"),
    type = c("patents", "us_patent_citations", "inventors", "locations"),
    ids = NULL, dates = NULL, size = 5) {
  config_path = "references/config.yaml"
  
  mode <- arg_match(mode)
  type <- arg_match(type)
  
  params <- read_yaml(config_path) |>
    pluck(mode, type)
  
  pluck(params, "o", "size") <- size
  
  if (type == "patents") {
    # something with dates
  } else {
    # something with ids, e.g.,
    pluck(params, "q", 1) <- c("a", "b", "c")
  }
}

# Tests ----

# client <- make_client()
# get_patents <- client$get_patents
# get_related <- client$get_related
# patent_params <- make_params("patents", size = 5)

# patents <- get_patents(patent_params, n_requests = 7)

# inventor_ids <- patents |>
#  bind_rows() |>
#  unnest_wider(inventors) |>
#  mutate(inventor_id = basename(inventor)) |>
#  pull(inventor_id) |>
#  unique()

# inventor_params <- make_params("inventors", ids = inventor_ids, size = 3)

# inventors <- get_related("inventors", inventor_params, n_requests = 3)

# location_ids <- inventors |>
#  bind_rows() |>
#  mutate(location_id = basename(inventor_lastknown_location)) |>
#  pull(location_id) |>
#  unique()

# location_params <- make_params("locations", ids = location_ids, size = 3)

# locations <- get_related("locations", location_params, n_requests = 3)

# patent_ids <- patents |>
#  bind_rows() |>
#  pull(patent_id) |>
#  unique()

# citations_params <- make_params("us_patent_citations", ids = patent_ids, size = 3)

# citations <- get_related("us_patent_citations", citations_params, n_requests = 3)
