# lse-diss
Dissertation for the MSc in Economics at the LSE

## Overview

Analyse how localised knowledge spillovers are and how much this has changed (e.g., pre and post pandemic).

## Roadmap

I want to incorporate the pagination option so I can extract a full dataset over a few years, but it might instead be better just to download bulk data from Patentsview.

Before that, I think play around with the embedding stuff to see how to implement it. I will read a few papers to do that.

After that, I can either scale the thing and do the test or see if I can find better address data.

I got HTTP 414 URI Too Long when trying to get some data when sending 1000 IDs.

Might be worth changing from GET to POST somehow. Maybe just changing the add_query_params fn.

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
