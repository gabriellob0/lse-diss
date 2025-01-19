# PatentsView API Client

library(httr2)
library(purrr)

make_client <- function(api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  if (identical(api_key, "")) {
    stop("No API key found, please create PATENTSVIEW_API_KEY environmental variable.")
  }
  
  ENDPOINTS <- list(
    patents = "patent",
    citations = "patent/us_patent_citation",
    inventors = "inventor",
    locations = "location"
  )
  
  #NOTE: I am not passing the api_key as an argument and I hope this makes it
  #hard coded here.
  make_request <- function(endpoint, params) {
    request("https://search.patentsview.org") |>
      req_url_path("api", "v1", endpoint) |>
      req_headers("X-Api-Key" = api_key) |>
      req_throttle(45 / 60) |>
      req_body_json(compact(params)) |>
      req_perform() |>
      req_body_json()
  }
  
  iterate_requests <- function() {
    
  }
  
  get_patents <- function(params) {
    
  }
  
  get_related <- function(
    type = c("citations", "inventors", "locations"),
    params) {
    type <- arg_match(type)
  }
  
  list(get_patents, get_related)
}

make_params <- function(
    type = c("patents", "citations", "inventors", "locations"),
    dates, ids, fields, size) {
  type <- arg_match(type)
  
  params <- list(
    q = query,
    f = fields,
    s = list(list(patent_id = "asc")),
    o = options
  )
}