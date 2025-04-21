library(fs)
library(arrow)
library(dplyr)
library(ggplot2)

results <- read_parquet(path("data", "processed", "results.parquet"))

all <- filter(results, cpc_section == "All")
other <- filter(results, cpc_section != "All")

ggplot(all, aes(x = distance, y = density)) +
  geom_ribbon(aes(ymin = lower_local, ymax = upper_local), alpha=0.5) +
  geom_line() +
  theme_minimal() +
  labs(
    x = "Distance",
    y = "Density"
  ) +
  theme(
    text = element_text(family = "Libertinus Serif", face="bold")
  )

ggplot(other, aes(x = distance, y = density)) +
  geom_ribbon(aes(ymin = lower_local, ymax = upper_local), alpha=0.5) +
  geom_line() +
  facet_wrap(~ cpc_section, ncol = 2) +
  theme_minimal() +
  labs(
    x = "Distance",
    y = "Density"
  ) +
  theme(
    text = element_text(family = "Libertinus Serif", face="bold")
  )
