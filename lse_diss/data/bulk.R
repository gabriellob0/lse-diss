library(fs)
library(httr2)
library(arrow)
library(purrr)

get_bulk_data <- function(urls, output_dir = "data/raw") {
  dir_create(path(output_dir, "temp"))

  process_file <- function(url, name) {
    message(sprintf("Processing %s...", name))

    zip_path <- path(output_dir, "temp", sprintf("%s.zip", name))
    tsv_path <- path(output_dir, "temp", sprintf("%s.tsv", name))
    parquet_path <- path(output_dir, sprintf("%s.parquet", name))

    if (file_exists(parquet_path)) {
      message(sprintf("Skipping %s - already processed", name))
      return(TRUE)
    }

    req <- request(url) %>%
      req_progress() %>%
      req_retry(max_tries = 3)

    req_perform(req, path = zip_path)

    utils::unzip(zip_path, exdir = path(output_dir, "temp"))

    tsv_path |>
      open_dataset(format = "tsv") |>
      write_parquet(parquet_path)

    file_delete(zip_path)
    file_delete(tsv_path)
  }

  imap(urls, safely(process_file))
}
