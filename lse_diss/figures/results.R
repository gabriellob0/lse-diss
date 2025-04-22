library(fs)
library(arrow)
library(dplyr)
library(tidyr)
library(ggplot2)
library(gt)

results <- read_parquet(path("data", "processed", "results.parquet"))

all <- results |>
  filter(cpc_section == "All")



other <- filter(results, cpc_section != "All")

all_plot <- ggplot(all, aes(x = distance, y = density)) +
  geom_ribbon(
    aes(ymin = lower_band, ymax = upper_band, fill = "Global"),
    color = "black", linetype = "dashed"
  ) +
  geom_ribbon(
    aes(ymin = lower_local, ymax = upper_local, fill = "Local"),
    alpha = 0.4
  ) +
  geom_line() +
  theme_minimal() +
  labs(
    x = "Distance",
    y = "Density"
  ) +
  theme(
    text = element_text(family = "Libertinus Serif", face = "bold")
  ) +
  scale_y_continuous(labels = scales::scientific) +
  scale_fill_manual(
    name = "Band Type",
    values = c("Global" = "transparent", "Local" = "black"),
    guide = guide_legend(
      override.aes = list(
        alpha = c(0, 0.4),
        color = c("black", NA),
        linetype = c("dashed", "blank")
      )
    )
  )

other_plot <- ggplot(other, aes(x = distance, y = density)) +
  geom_ribbon(
    aes(ymin = lower_band, ymax = upper_band, fill = "Global"),
    color = "black", linetype = "dashed"
  ) +
  geom_ribbon(
    aes(ymin = lower_local, ymax = upper_local, fill = "Local"),
    alpha = 0.4
  ) +
  geom_line() +
  facet_wrap(~ cpc_section, ncol = 2) +
  theme_minimal() +
  labs(
    x = "Distance",
    y = "Density"
  ) +
  theme(
    text = element_text(family = "Libertinus Serif", face = "bold")
  ) +
  scale_y_continuous(labels = scales::scientific) +
  scale_fill_manual(
    name = "Band Type",
    values = c("Global" = "transparent", "Local" = "black"),
    guide = guide_legend(
      override.aes = list(
        alpha = c(0, 0.4),
        color = c("black", NA),
        linetype = c("dashed", "blank")
      )
    )
  )

global_test <- results |>
  mutate(
    Localisation = if_else(density>=upper_band, 1, 0),
    Dispersion = if_else(density<=lower_band, 1, 0)
  ) |>
  filter(Localisation == 1 | Dispersion == 1) |>
  select(cpc_section, Localisation, Dispersion) |>
  distinct() |>
  group_by(cpc_section) |>
  summarise(Localisation = sum(Localisation), Dispersion = sum(Dispersion)) |>
  mutate(
    Localisation = if_else(Localisation==1, "Yes", "No"),
    Dispersion = if_else(Dispersion==1, "Yes", "No")
  ) |> 
  arrange(
    case_when(
      cpc_section == "All" ~ 1,
      TRUE ~ 2
    ),
    cpc_section
  ) |>
  gt() |>
  tab_header(
    title = "Table 3",
    subtitle = "Global localisation test results"
  ) |>
  cols_label(cpc_section = "CPC section") |> 
  opt_table_font(font = "Libertinus Serif Semibold") |>
  tab_source_note(
    "Notes: I define a patent class as localised when the density crosses the upper band of the global confidence intervals. Conversely, a class is dispersed when it crosses the lower bands."
  ) |>
  tab_options(table.width = pct(60))


gtsave(global_test, path("reports", "drafts", "table3.png"), expand = 10)
ggsave(path("reports", "drafts", "figure3.png"), all_plot)
ggsave(path("reports", "drafts", "figure4.png"), other_plot, height = 9, width = 7)
