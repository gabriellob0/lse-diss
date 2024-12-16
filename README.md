# lse-diss
Dissertation for the MSc in Economics at the LSE

## Overview

Analyse how localised knowledge spillovers are and how much this has changed (e.g., pre and post pandemic).

## Roadmap

Next, probably play with the API data and extract some stuff with NLP.

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
