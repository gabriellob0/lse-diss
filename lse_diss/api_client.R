# PatentSearch API Client ----

library(httr2)
library(purrr)
library(rlang)

make_client <- function(api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  if (identical(api_key, "")) {
    stop("No API key found, please create PATENTSVIEW_API_KEY environmental variable.")
  }
  
  ENDPOINTS <- list(
    patents = "patent",
    us_patent_citations = "patent/us_patent_citation/",
    inventors = "inventor",
    locations = "location"
  )
  
  make_request <- function(endpoint, params) {
    request("https://search.patentsview.org") |>
      req_url_path("api", "v1", endpoint) |>
      req_headers("X-Api-Key" = api_key) |>
      req_throttle(45 / 60) |>
      req_body_json(compact(params))
  }
  
  next_req <- function(resp, req) {
    data <- resp |>
      resp_body_json()
    
    if (length(data) == 0) {
      return(NULL)
    }
    
    total_hits <- pluck(data, "total_hits")
    #print(total_hits)
    
    signal_total_pages(ceiling(total_hits / 1000))
    
    id_field <- names(pluck(req, "body", "data", "s", 1))
    
    # NOTE: This is the cursor
    pluck(req, "body", "data", "o", "after") <- pluck(data, -1, -1, id_field)
    
    req
  }
  
  get_patents <- function(params, n_requests = Inf) {
    first_req <- make_request(ENDPOINTS[["patents"]], params)
    
    resps <- req_perform_iterative(
      first_req,
      next_req,
      max_reqs = n_requests,
      progress = TRUE
    )
    
    resps_successes(resps) |>
      resps_data(\(resp) resp_body_json(resp)$patents)
  }
  
  get_related <- function(type = c("us_patent_citations", "inventors", "locations"),
                          params, n_requests = Inf) {
    type <- arg_match(type)
    
    first_req <- make_request(ENDPOINTS[[type]], params)
    
    resps <- req_perform_iterative(
      first_req,
      next_req,
      max_reqs = n_requests,
      progress = TRUE
    )
    
    resps_successes(resps) |>
      resps_data(\(resp) resp_body_json(resp)[[type]])
  }
  
  list(get_patents = get_patents, get_related = get_related)
}

make_params <- function(
    type = c("patents", "us_patent_citations", "inventors", "locations"),
    fields = NULL, ids, dates = c("2023-01-01", "2024-01-01"), size = 100) {
  type <- arg_match(type)
  
  ID_FIELDS <- list(
    patents = "patent_id",
    us_patent_citations = "citation_patent_id",
    inventors = "inventor_id",
    locations = "location_id"
  )
  
  DEFAULT_FIELDS <- list(
    patents = c("patent_id", "patent_date", "patent_abstract", "inventors"), # TODO: assignees
    us_patent_citations = c("patent_id", "citation_patent_id", "citation_category"),
    inventors = c("inventor_id", "inventor_lastknown_location"),
    locations = c("location_id", "location_latitude", "location_longitude")
  )
  
  if (type == "patents") {
    query <- list(
      "_and" = list(
        list("_gte" = list("patent_date" = dates[1])),
        list("_lte" = list("patent_date" = dates[2])),
        list("_eq" = list("assignees.assignee_type" = "2")),
        #list("_or" = list(list("assignees.assignee_type" = "2"), list("assignees.assignee_type" = "3"))),
        list("_eq" = list("assignees.assignee_country" = "US")),
        list("_gte" = list("patent_num_times_cited_by_us_patents" = 1)),
        list("_eq" = list("patent_type" = "utility")),
        list("_eq" = list("inventors.inventor_country" = "US"))
      )
    )
  } else {
    query <- setNames(list(ids), ID_FIELDS[[type]])
  }
  
  # NOTE: All parameters are required when using POST
  params <- list(
    q = query,
    f = fields %||% DEFAULT_FIELDS[[type]],
    s = list(setNames(list("asc"), ID_FIELDS[[type]])),
    o = list(size = size)
  )
}

# Tests ----

#client <- make_client()
#get_patents <- client$get_patents
#get_related <- client$get_related
#patent_params <- make_params("patents", size = 5)

#patents <- get_patents(patent_params, n_requests = 7)

#inventor_ids <- patents |>
#  bind_rows() |>
#  unnest_wider(inventors) |>
#  mutate(inventor_id = basename(inventor)) |>
#  pull(inventor_id) |>
#  unique()

#inventor_params <- make_params("inventors", ids = inventor_ids, size = 3)

#inventors <- get_related("inventors", inventor_params, n_requests = 3)

#location_ids <- inventors |>
#  bind_rows() |>
#  mutate(location_id = basename(inventor_lastknown_location)) |>
#  pull(location_id) |>
#  unique()

#location_params <- make_params("locations", ids = location_ids, size = 3)

#locations <- get_related("locations", location_params, n_requests = 3)

#patent_ids <- patents |>
#  bind_rows() |>
#  pull(patent_id) |>
#  unique()

#citations_params <- make_params("us_patent_citations", ids = patent_ids, size = 3)

#citations <- get_related("us_patent_citations", citations_params, n_requests = 3)
