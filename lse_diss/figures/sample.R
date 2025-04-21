library(fs)
library(duckplyr)
library(gt)
library(ggplot2)
library(Rtsne)
library(tidyr)
library(stringr)
library(purrr)
library(viridis)
library(maps)
library(sf)


# Table 1 ----
make_table1 <- function(
  interim_controls_path = path("data", "interim", "controls", "*"),
  processed_controls_path = path("data", "processed", "controls.parquet"),
  save_path = path("reports", "drafts", "table1.png")
) {
  interim_controls <- read_parquet_duckdb(
    (path("data", "interim", "controls", "*"))
  )
  processed_controls <- read_parquet_duckdb(
    (path("data", "processed", "controls.parquet"))
  )

  interim_controls_counts <- interim_controls |>
    summarise(
      count = n(), #214886441
      citing_count = n_distinct(citing_patent_id), #2758
      cited_count = n_distinct(cited_patent_id), #1199
      control_count = n_distinct(control_patent_id) #306966
    ) |>
    collect() |>
    mutate(stage = "Pre-similarity matching")

  processed_controls_counts <- processed_controls |>
    summarise(
      count = n(),
      citing_count = n_distinct(citing_patent_id),
      cited_count = n_distinct(cited_patent_id),
      control_count = n_distinct(control_patent_id)
    ) |>
    collect() |>
    mutate(stage = "Post-similarity matching")

  bind_rows(interim_controls_counts, processed_controls_counts) |>
    gt(rowname_col = "stage") |>
    tab_header(
      title = "Table 1",
      subtitle = "Sample sizes before and after similarity matching"
    ) |>
    tab_spanner(
      label = "Unique patents",
      columns = c(cited_count, citing_count, control_count)
    ) |>
    cols_label(
      cited_count = "Cited",
      citing_count = "Citing",
      control_count = "Control",
      count = "Observations"
    ) |>
    fmt_integer() |>
    tab_source_note(
      "Notes: The pre-similarity matching data includes controls with an application date within 180 days of the citing patent's application date that do not cite the cited patent or have any inventors or assignees in common. The post-similarity matching data consists of the intersection of the first group with the 308 nearest neighbours over all citing and control patents."
    ) |>
    opt_table_font(font = "Libertinus Serif Semibold") |>
    tab_options(table.width = pct(60)) |>
    gtsave(save_path, expand = 10)
}


# Table 2 ----
make_table2 <- function(
  cited_classes_path = path("data", "processed", "classes.parquet"),
  controls_path = path("data", "processed", "controls.parquet"),
  save_path = path("reports", "drafts", "table2.png")
) {
  cited_classes <- read_parquet_duckdb(cited_classes_path)
  controls <- read_parquet_duckdb(controls_path)

  cpc_sections <- c(
    "Human necessities",
    "Performing operations; transporting",
    "Chemistry; metallurgy",
    "Textiles; paper",
    "Fixed constructions",
    "Mechanical engineering; lighting; heating; weapons; blasting engines or pumps",
    "Physics",
    "Electricity",
    "General tagging of new technological developments; general tagging of cross-sectional technologies spanning over several sections of the IPC; technical subjects covered by former USPC cross-reference art collections [XRACs] and digests"
  )

  table2_data <- controls |>
    left_join(cited_classes, by = join_by(cited_patent_id == patent_id)) |>
    collect() |>
    mutate(concat = str_c(cited_patent_id, citing_patent_id)) |>
    summarise(
      cited_count = n_distinct(cited_patent_id),
      citing_pairs = n_distinct(concat),
      triple_count = n(),
      .by = cpc_section
    ) |>
    arrange(cpc_section) |>
    mutate(Description = cpc_sections)

  table2 <- table2_data |>
    gt() |>
    tab_header(
      title = "Table 2",
      subtitle = "Counts of cited patents, citing pairs, and patent triples by CPC section"
    ) |>
    cols_label(
      cpc_section = "CPC section",
      cited_count = "Cited patents",
      citing_pairs = "Citing pairs",
      triple_count = "Patent triples"
    ) |>
    cols_move_to_end(c(cited_count, citing_pairs, triple_count)) |>
    tab_spanner(
      label = "Counts",
      columns = c(cited_count, citing_pairs, triple_count)
    ) |>
    opt_table_font(font = "Libertinus Serif Semibold") |>
    fmt_integer() |>
    tab_source_note(
      "Notes: Cited patent counts refer to the count of unique cited patents in the matched sample. A citing pair is a unique cited-citing patent combination. A triple is a cited, citing, and control patent. Hence, multiple triples exist for each cited patent and each cited-citing pair. The definitions of the CPC section are from the European Patent Office website."
    ) |>
    tab_options(table.width = pct(60)) |>
    gtsave(save_path, expand = 10)
}

print(1)

# Figure 1 ----
make_figure1 <- function(
  cited_classes_path = path("data", "processed", "classes.parquet"),
  embeddings_path = path("data", "processed", "embeddings", "*"),
  save_path = path("reports", "drafts", "figure1.png")
) {
  cited_classes <- read_parquet_duckdb(cited_classes_path)
  embeddings <- read_parquet_duckdb(embeddings_path)

  embedding_sample <- embeddings |>
    slice_sample(n = 50000)

  tsne <- embedding_sample |>
    select(embedding) |>
    unnest_wider(embedding, names_sep = "_") |>
    Rtsne(check_duplicates = FALSE) |>
    keep_at("Y") |>
    pluck(1) |>
    as_tibble(.name_repair = "minimal") |>
    rename(tsne1 = 1, tsne2 = 2)

  figure1_data <- embedding_sample |>
    select(-embedding) |>
    bind_cols(tsne) |>
    left_join(cited_classes, by = join_by(patent_id)) |>
    filter(!is.na(cpc_section)) |>
    group_by(patent_id) |>
    slice_sample(n = 1) |>
    ungroup()

  plot <- ggplot(
    figure1_data,
    aes(x = tsne1, y = tsne2, colour = cpc_section)
  ) +
    geom_point() +
    theme_void() +
    labs(colour = "CPC section") +
    theme(text = element_text(family = "Libertinus Serif", face="bold"))

  ggsave(save_path, plot)
}


# Figure 2 ----
make_figure2 <- function(
  locations_path = path("data", "interim", "locations.parquet"),
  save_path = path("reports", "drafts", "figure2.png")
) {
  locations <- locations_path |>
    read_parquet_duckdb() |>
    filter(
      longitude >= -125,
      longitude <= -66.5,
      latitude >= 24,
      latitude <= 49.5
    ) |>
    collect()

  us_states <- st_as_sf(map("state", plot = FALSE, fill = TRUE))

  plot <- ggplot() +
    geom_sf(data = us_states, fill = "white") +
    stat_binhex(
      data = locations,
      aes(x = longitude, y = latitude, fill = after_stat(log(count))),
      bins = 100
    ) +
    theme_minimal() +
    theme(
      text = element_text(family = "Libertinus Serif", face="bold")
    ) +
    scale_fill_viridis() +
    labs(fill = "Log count", x = "Longitude", y = "Latitude")

  ggsave(save_path, plot, height = 4, width = 7)
}

# run ----
make_table1()
make_table2()

make_figure1()
make_figure2()
