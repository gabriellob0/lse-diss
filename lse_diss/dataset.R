library(httr2)
library(jsonlite)
library(checkmate)

create_base_request <- function(endpoint, api_key) {
  request("https://search.patentsview.org") |>
    req_url_path(paste0("/api/v1/", endpoint, "/")) |>
    req_headers("X-Api-Key" = api_key) |>
    req_throttle(45 / 60)
}

add_query_params <- function(req, query, fields, sort = NULL, options = NULL) {
  params <- list(
    q = toJSON(query, auto_unbox = TRUE),
    f = toJSON(fields, auto_unbox = TRUE)
  )
  
  if (!is.null(sort)) {
    params$s = toJSON(sort, auto_unbox = TRUE)
  }
  
  if (!is.null(options)) {
    params$o = toJSON(options, auto_unbox = TRUE)
  }
  
  req_url_query(req, !!!params)
}

execute_request <- function(req) {
  req |>
    req_perform() |>
    resp_body_json()
}

get_patents <- function(
    fields = c("patent_id", "patent_title", "patent_date"),
    start_date = "2023-01-01",
    end_date = "2024-01-01",
    size = 10,
    api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  # Argument validation
  assertString(api_key, min.chars = 1)
  assertCharacter(fields, min.len = 1, unique = TRUE)
  assertDate(as.Date(start_date))
  assertDate(as.Date(end_date))
  assertNumber(size, lower = 1, upper = 1000, finite = TRUE)

  # Create query with all filtering conditions
  query <- list(
    "_and" = list(
      list("_gte" = list("patent_date" = start_date)),
      list("_lte" = list("patent_date" = end_date)),
      list("_eq" = list("assignees.assignee_type" = "2")),
      list("_eq" = list("assignees.assignee_country" = "US")),
      list("_gte" = list("patent_num_times_cited_by_us_patents" = 1)),
      list("_eq" = list("patent_type" = "utility"))
    )
  )

  # Create options object
  options <- list(size = size)
  
  # Create and perform request
  base_req <- create_base_request("patent", api_key)

  req_with_query <- base_req |>
    add_query_params(
      query = query,
      fields = fields,
      sort = list(list(patent_date = "asc")),
      options = list(size = size)
    )

  execute_request(req_with_query)
}

get_citing_patents <- function(
    patent_ids,
    fields = c("patent_id", "citation_patent_id", "citation_category"),
    api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  # Argument validation
  assertString(api_key, min.chars = 1)
  assertCharacter(patent_ids, min.len = 1, unique = TRUE)
  assertCharacter(fields, min.len = 1, unique = TRUE)

  query <- list("citation_patent_id" = patent_ids)

  base_req <- create_base_request("patent/us_patent_citation", api_key)

  req_with_query <- base_req |>
    req_url_query(
      q = toJSON(query, auto_unbox = TRUE),
      f = toJSON(fields, auto_unbox = TRUE)
    )

  resp <- req_with_query |>
    req_perform() |>
    resp_body_json()
}

get_inventors <- function(
    inventors,
    fields = c("inventor_id", "inventor_lastknown_location"),
    api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  # Argument validation
  assertString(api_key, min.chars = 1)

  query <- list("inventor_id" = inventors)

  # Create request
  base_req <- create_base_request("inventor", api_key)

  req_with_query <- base_req |>
    req_url_query(
      q = toJSON(query, auto_unbox = TRUE),
      f = toJSON(fields, auto_unbox = TRUE)
    )

  # Perform request and return response
  resp <- req_with_query |>
    req_perform() |>
    resp_body_json()
}


get_locations <- function(
    locations,
    fields = c("location_id", "location_name", "location_latitude", "location_longitude"),
    api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  # Argument validation
  assertString(api_key, min.chars = 1)

  query <- list("location_id" = locations)

  # Create request
  base_req <- create_base_request("location", api_key)

  req_with_query <- base_req |>
    req_url_query(
      q = toJSON(query, auto_unbox = TRUE),
      f = toJSON(fields, auto_unbox = TRUE)
    )

  # Perform request and return response
  resp <- req_with_query |>
    req_perform() |>
    resp_body_json()
}
