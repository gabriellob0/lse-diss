library(httr2)
library(checkmate)


# Helpers -----------------------------------------------------------------

get_api_key <- function() {
  key <- Sys.getenv("PATENTSVIEW_API_KEY")
  if (identical(key, "")) {
    stop("No API key found, please supply with PATENTSVIEW_API_KEY env var")
  }
  key
}

create_request <- function(
    endpoint,
    api_key,
    query,
    fields = NULL,
    sort = NULL,
    options = NULL) {
  params <- list(q = query, f = fields, s = sort, o = options)
  params <- params[!sapply(params, is.null)]

  req <- request("https://search.patentsview.org") |>
    req_url_path("/api/v1/") |>
    req_url_path_append(endpoint) |>
    req_headers("X-Api-Key" = api_key) |>
    req_throttle(45 / 60)

  req_body_json(req, params)
}

execute_request <- function(req) {
  req |>
    req_perform() |>
    resp_body_json()
}


# Patents -----------------------------------------------------------------

build_patent_query <- function(start_date, end_date) {
  assertDate(as.Date(start_date))
  assertDate(as.Date(end_date))

  if (as.Date(start_date) > as.Date(end_date)) {
    stop("start_date must be before or equal to end_date")
  }

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

get_patents <- function(
    fields = c("patent_id", "patent_title", "patent_date"),
    start_date = "2023-01-01",
    end_date = "2024-01-01",
    size = 10,
    api_key = get_api_key()) {
  # Argument validation
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
    api_key = get_api_key()) {
  query <- build_patent_query(start_date, end_date)

  next_req <- function(resp, req) {
    data <- resp_body_json(resp)
    if (is.null(data$patents) || length(data$patents) == 0) {
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


# IDs ---------------------------------------------------------------------

configure_id_query <- function(
    query_type = c("citations", "inventors", "locations"),
    fields = NULL) {
  endpoint_defaults <- list(
    "citations" = list(
      endpoint = "patent/us_patent_citation",
      query_param = "citation_patent_id",
      default_fields = c("patent_id", "citation_patent_id", "citation_category")
    ),
    "inventors" = list(
      endpoint = "inventor",
      query_param = "inventor_id",
      default_fields = c("inventor_id", "inventor_lastknown_location")
    ),
    "locations" = list(
      endpoint = "location",
      query_param = "location_id",
      default_fields = c("location_id", "location_name", "location_latitude", "location_longitude")
    )
  )

  query_type <- match.arg(query_type)
  config <- endpoint_defaults[[query_type]]

  if (is.null(fields)) {
    fields <- config$default_fields
  }

  list(
    endpoint = config$endpoint,
    query_param = config$query_param,
    fields = fields
  )
}

get_by_id <- function(
    ids,
    query_type = c("citations", "inventors", "locations"),
    fields = NULL,
    api_key = get_api_key()) {
  # Validate inputs
  assertCharacter(ids, min.len = 1, unique = TRUE)

  config <- configure_id_query(query_type, fields)

  # Create the request
  req <- create_request(
    config$endpoint,
    api_key,
    query = setNames(list(ids), config$query_param),
    fields = config$fields
  )

  # Execute and return the request
  execute_request(req)
}
