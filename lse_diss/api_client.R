# PatentsView API Client

library(httr2)
library(purrr)

make_client <- function(api_key) {
  if (identical(api_key, "")) {
    stop("No API key found, please create PATENTSVIEW_API_KEY environmental variable.")
  }
  
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
  
  get_patents <- function(params) {
    first_page <- make_request("patent", params)
    
    next_page <- function(resp) {
      if (length(resp$patents) == 0) {
        return(NULL)
      }
      
      LAST_ID <- pluck(resp$patents, -1, "patent_id")
      
      make_request()
    }
    
    resp <- req_perform_iterative(
      first_page,
      next_page,
      max_reqs = Inf
    )
  }
  
  get_related <- function() {
    
  }
  
  list(get_patents, get_related, make_request)
}

make_params <- function(
    type = c("patents", "citations", "inventors", "locations")) {
  type <- arg_match(type)
  
  params <- list(
    q = query,
    f = fields,
    s = sort,
    o = options
  )
}