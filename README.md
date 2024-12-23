# lse-diss
Dissertation for the MSc in Economics at the LSE

## Overview

Analyse how localised knowledge spillovers are and how much this has changed (e.g., pre and post pandemic).

## Roadmap

I have downloaded some bulk data with the function, but the citation data is too large to do like that and process in R.

I have downloaded it separately and processed it in Python. I think a strategy to keep it reproducible will be to:

1. Download + unzip with the function I created, keep it in external
2. Use the polars function to convert from tsv to parquet.

After that, I can either scale the thing and do the test or see if I can find better address data.

I got HTTP 414 URI Too Long when trying to get some data when sending 1000 IDs.

Might be worth changing from GET to POST somehow. Maybe just changing the add_query_params fn.

Scaling strategy:

1. Pick base year - I will go with 2010 for now
2. Download ALL abstracts IDs, inventor IDs, and some sort of date since 2010
3. For patents in the base year, find all the citations
4. For each citation, construct the dataset of possible controls
5. (restrict by date, like 3 months, and remove any other citing patents)
6. Embbed all these abstracts and do nearest neighbour search
7. Should have a three column dataset (or maybe each group should have three patents)
8. Create a dataset with the location of each patent (created from iventor locations)
9. Match each dataset so I have location for all patents.

## Data

Data from the USPTO API. The idea for sample construction right now is:

1. Pick sample of patents (e.g., university asignees) plus originating year, mainly to make it computationally viable.
2. Randomly select inventor of patent and assign geographic location (alternatively, use JTH method).
3. Match inventor location to feature in US map.
4. Restric the sample (e.g., remove no geographic data, self-cites, no assignee)
5. Find nearest patent by semantic similarity between abstracts within a data range.
6. Find distances between controls and citing patents to originating ones.

also see: https://onlinelibrary.wiley.com/doi/10.1111/jems.12262

Useful data dictionary from: https://patentsview.org/download/data-download-dictionary

assignee_type = classification of assignee (1 - Unassigned, 2 - US Company or Corporation, 3 - Foreign Company or Corporation, 4 - US Individual, 5 - Foreign Individual, 6 - US Federal Government, 7 - Foreign Government, 8 - US County Government, 9 - US State Government. Note: A "1" appearing before any of these codes signifies part interest

## References

Interesting papers that might be useful:

https://academic.oup.com/qje/article/134/2/647/5218522#133115040

https://eml.berkeley.edu/~pkline/papers/KPWZ_QJE_2019.pdf

https://www.uspto.gov/sites/default/files/documents/oce-women-patentees-report.pdf

https://www.journals.uchicago.edu/doi/full/10.1086/723636

Keeping in EndNote for now.
