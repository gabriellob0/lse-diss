library(httr2)
library(jsonlite)
library(checkmate)

fetch_patents <- function(
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

  # Create date query
  date_query <- list(
    "_and" = list(
      list("_gte" = list("patent_date" = start_date)),
      list("_lte" = list("patent_date" = end_date))
    )
  )
  
  # Create options object
  options <- list(size = size)

  base_req <- request("https://search.patentsview.org") |>
    req_url_path("/api/v1/patent/") |>
    req_headers("X-Api-Key" = api_key) |>
    req_throttle(45 / 60) # Rate limit as per API docs

  req_with_query <- base_req |>
    req_url_query(
      q = toJSON(date_query, auto_unbox = TRUE),
      f = toJSON(fields, auto_unbox = TRUE),
      s = '[{"patent_date":"asc"}]',
      o = toJSON(options, auto_unbox = TRUE)
    )
  
  resp <- req_with_query |>
    req_perform() |>
    resp_body_json()
}


fetch_citations <- function(api_key = Sys.getenv("PATENTSVIEW_API_KEY")) {
  base_req <- request("https://search.patentsview.org") |>
    req_url_path("/api/v1/patent/us_patent_citation/") |>
    req_headers("X-Api-Key" = api_key) |>
    req_throttle(45 / 60) # Rate limit as per API docs
  
  req_with_query <- base_req |>
    req_url_query(
      q = '{"citation_patent_id":"7861317"}',
      s = '[{"citation_date":"asc"}]'
    )
  
  resp <- req_with_query |>
    req_perform() |>
    resp_body_json()
}
