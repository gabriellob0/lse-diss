source("lse_diss/dataset.R")

patents <- fetch_patents()

saveRDS(patents, file = "data/raw/patents.rds")