# PatentsView API Client

library(httr2)
library(purrr)

# Configuration -----------------------------------------------------------
ENDPOINTS <- list(
  patent = list(
    path = "patent",
    default_fields = c("patent_id", "patent_title", "patent_date"),
    id_field = "patent_id"
  ),
  citations = list(
    path = "patent/us_patent_citation",
    default_fields = c("patent_id", "citation_patent_id", "citation_category"),
    id_field = "citation_patent_id"
  ),
  inventors = list(
    path = "inventor",
    default_fields = c("inventor_id", "inventor_lastknown_location"),
    id_field = "inventor_id"
  ),
  locations = list(
    path = "location",
    default_fields = c("location_id", "location_name", "location_latitude", "location_longitude"),
    id_field = "location_id"
  )
)

CONFIG <- list(
  base_url = "https://search.patentsview.org",
  rate_limit = 45 / 60, # requests per second
  max_page_size = 1000
)

# Core functions ----------------------------------------------------------
get_api_key <- function() {
  key <- Sys.getenv("PATENTSVIEW_API_KEY")
  if (identical(key, "")) {
    stop("No API key found, please supply with PATENTSVIEW_API_KEY env var")
  }
  key
}

create_request <- function(endpoint, query, fields = NULL, sort = NULL,
                           options = NULL, api_key = get_api_key()) {
  params <- list(
    q = query,
    f = fields,
    s = sort,
    o = options
  )

  request(CONFIG$base_url) |>
    req_url_path("api", "v1", endpoint) |>
    req_headers("X-Api-Key" = api_key) |>
    req_throttle(CONFIG$rate_limit) |>
    req_body_json(compact(params))
}

execute_request <- function(req) {
  req |>
    req_perform() |>
    resp_body_json()
}

create_date_query <- function(start_date, end_date) {
  start <- as.Date(start_date)
  end <- as.Date(end_date)

  if (start > end) {
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


# API Functions -----------------------------------------------------------
get_patents <- function(
    start_date = "2023-01-01",
    end_date = "2024-01-01",
    fields = c("patent_id", "patent_title", "patent_date"),
    size = 10,
    api_key = get_api_key()) {
  # Validate size
  if (size < 1 || size > CONFIG$max_page_size) {
    stop(sprintf("size must be between 1 and %d", CONFIG$max_page_size))
  }

  query <- create_date_query(start_date, end_date)
  endpoint <- ENDPOINTS$patent

  req <- create_request(
    endpoint$path,
    query = query,
    fields = fields %||% endpoint$default_fields,
    sort = list(list(patent_date = "asc")),
    options = list(size = size),
    api_key = api_key
  )

  execute_request(req)
}

get_all_patents <- function(
    start_date = "2023-01-01",
    end_date = "2024-01-01",
    fields = NULL,
    api_key = get_api_key()) {
  query <- create_date_query(start_date, end_date)
  endpoint <- ENDPOINTS$patent

  next_req <- function(resp, req) {
    data <- resp_body_json(resp)
    if (is.null(data$patents) || length(data$patents) == 0) {
      return(NULL)
    }

    last_id <- pluck(data$patents, -1, "patent_id")

    create_request(
      endpoint$path,
      query = query,
      fields = fields %||% endpoint$default_fields,
      sort = list(list(patent_id = "asc")),
      options = list(size = CONFIG$max_page_size, after = last_id),
      api_key = api_key
    )
  }

  first_req <- create_request(
    endpoint$path,
    query = query,
    fields = fields %||% endpoint$default_fields,
    sort = list(list(patent_id = "asc")),
    options = list(size = CONFIG$max_page_size),
    api_key = api_key
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

get_related <- function(
    ids,
    type = c("citations", "inventors", "locations"),
    fields = NULL,
    api_key = get_api_key()) {
  # Validate inputs
  if (!is.character(ids) || length(ids) < 1 || any(duplicated(ids))) {
    stop("Invalid IDs provided")
  }

  type <- match.arg(type)
  endpoint <- ENDPOINTS[[type]]

  query <- setNames(list(ids), endpoint$id_field)

  req <- create_request(
    endpoint$path,
    query = query,
    fields = fields %||% endpoint$default_fields,
    api_key = api_key
  )

  execute_request(req)
}
