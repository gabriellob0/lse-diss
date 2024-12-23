library(httr2)
library(jsonlite)
library(checkmate)
library(purrr)

## TODO: more comprehensive function to get API key.

build_patent_query <- function(start_date, end_date) {
  assertDate(as.Date(start_date))
  assertDate(as.Date(end_date))

  list(
    "_and" = list(
      list("_gte" = list("patent_date" = start_date)),
      list("_lte" = list("patent_date" = end_date)),
      list("_eq" = list("assignees.assignee_type" = "2")),
      list("_eq" = list("assignees.assignee_country" = "US")),
      list("_gte" = list("patent_num_times_cited_by_us_patents" = 1)),
      list("_eq" = list("patent_type" = "utility"))
    )
  )
}

create_request <- function(
    endpoint,
    api_key,
    query,
    fields = NULL,
    sort = NULL,
    options = NULL) {
  req <- request("https://search.patentsview.org") |>
    req_url_path("/api/v1/") |>
    req_url_path_append(endpoint) |>
    req_headers("X-Api-Key" = api_key) |>
    req_throttle(45 / 60)

  params <- list(q = query, f = fields, s = sort, o = options) |>
    discard(is.null) |>
    map(\(x) toJSON(x, auto_unbox = TRUE))

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
  assertNumber(size, lower = 1, upper = 1000, finite = TRUE)

  query <- build_patent_query(start_date, end_date)

  req <- create_request(
    "patent",
    api_key,
    query = query,
    fields = fields,
    sort = list(list(patent_date = "asc")),
    options = list(size = size)
  )

  execute_request(req)
}

get_all_patents <- function(
    fields = c("patent_id", "patent_title", "patent_date"),
    start_date = "2023-01-01",
    end_date = "2024-01-01",
    api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  query <- build_patent_query(start_date, end_date)

  next_req <- function(resp, req) {
    data <- resp_body_json(resp)
    if (is.null(data$patents) | length(data$patents) == 0) {
      return(NULL)
    }

    last_patent_id <- data$patents[[length(data$patents)]]$patent_id

    create_request(
      "patent",
      api_key,
      query = query,
      fields = fields,
      sort = list(list(patent_id = "asc")),
      options = list(size = 1000, after = last_patent_id)
    )
  }

  first_req <- create_request(
    "patent",
    api_key,
    query = query,
    fields = fields,
    sort = list(list(patent_id = "asc")),
    options = list(size = 1000)
  )

  resps <- req_perform_iterative(
    first_req,
    next_req,
    max_reqs = Inf,
    progress = TRUE
  )

  # Process successful responses
  resps_successes(resps) |>
    resps_data(\(resp) resp_body_json(resp)$patents)
}


get_by_id <- function(
    ids,
    query_type = c("citations", "inventors", "locations"),
    fields = NULL,
    api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  # Validate inputs
  assertString(api_key, min.chars = 1)
  assertCharacter(ids, min.len = 1, unique = TRUE)

  # Define default fields for each query type
  default_fields <- list(
    "citations" = c("patent_id", "citation_patent_id", "citation_category"),
    "inventors" = c("inventor_id", "inventor_lastknown_location"),
    "locations" = c("location_id", "location_name", "location_latitude", "location_longitude")
  )

  # Validate query_type
  query_type <- match.arg(query_type)

  # Use default fields if not provided
  if (is.null(fields)) {
    fields <- default_fields[[query_type]]
  } else {
    # Validate user-provided fields
    assertCharacter(fields, min.len = 1, unique = TRUE)
  }

  # Map query types to endpoint names and query parameter names
  endpoint_map <- list(
    "citations" = list(
      endpoint = "patent/us_patent_citation",
      query_param = "citation_patent_id"
    ),
    "inventors" = list(
      endpoint = "inventor",
      query_param = "inventor_id"
    ),
    "locations" = list(
      endpoint = "location",
      query_param = "location_id"
    )
  )

  # Get the appropriate endpoint and query parameter
  endpoint_info <- endpoint_map[[query_type]]

  # Create the request
  req <- create_request(
    endpoint_info$endpoint,
    api_key,
    query = setNames(list(ids), endpoint_info$query_param),
    fields = fields
  )

  # Execute and return the request
  execute_request(req)
}
