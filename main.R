# Imports ----

source("lse_diss/data/make_client.R")
source("lse_diss/data/make_data.R")

# Data ----
client <- make_client()
make_data(client)
