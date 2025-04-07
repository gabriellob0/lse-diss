# lse-diss

Dissertation for my MSc in Economics at the LSE.

## Overview

I want to analyse the extent of geographic localisation using patent data. I use a matching estimator where non-citing patents serve as a control. The key idea is to improve control selection by using embedded patent abstracts to do the matching.

I might also check how this has changed over time and if localisation persists in longer periods. Previous papers were mainly limited to the NBER patent database. Patent controls seem to have been introduced by Jaffe et al., and they should have the same "technological and temporal distribution" as citing patents.

## Roadmap

The API client and the download script are working and completed. The only limitation with the current strategy is that I remove non-US inventors, which could allow some self-cites to go undetected. I also have the script to download the bulk data which is not incorporated in my main file. I intend to do so when I figure out what data I am using from the bulk downloads.

Ideally, these would also have some tests, but I don't think it is an immediate priority. Instead, I want to focus on validating the data. I want to have a separate validation file, should focus on missing data, duplicates, and string formatting.

I have done some feature engineering, primarly creating the patent location following the rule in Kerr and Kominer (2015): majority then inventor order. I think there is no harm in doing the joins by location_id at this stage in terms of compute time and memory; it should save a few lines of code down the line.

I have created the code for the treatment group, so I should create the control group next. I need to decide the fixed rule that I will use and understand the Overman and Duranton strategy applied to this case.

So, in no particular order:

* Tests for the API
* Incorporate bulk downloads and features into main
* Review citations in EndNote
* Rework data construction table
* Select embedding model and create control group

## Data

### Sample Construction Table

My advisor says to match based on application date. Also, he highlights that examiner added patents might care some information.

| API Field | Values | Notes | Source | Literature |
|---|---|---|---|---|
| assignee_type | I am using "2", which means a US company. | I still need to filter to ONLY US companies after the query. | <https://patentsview.org/download/data-download-dictionary> | JTH argues this information is not relevant. TFK also removes individual assignees. MNOT also restricts to non-gov patents. |
| assignee_country | I restrict to US. | Same as above. |  | MNOT restricts to the US. |
| patent_num_times_cited_by_us_patents |  | Useful to filter originating patents. |  |  |
| patent_type | Set to "utility". |  | <https://www.uspto.gov/web/offices/ac/ido/oeip/taf/data/patdesc.htm> |  |
| patent_date |  | Grant date. |  | JTH uses grant date to match controls. TFK does the opposite. (check) |
| assignee_id | To remove self-citations | Find from the URL in assignees.assignee. |  | JTH removes self-citations. |
| inventor_sequence |  | Order inventors appear in file. Might be useful for selecting location. |  |  |
| patent_earliest_application_date |  | Might be useful to set baseline originating year. |  | I think JTH uses this for originating years. TFK does the opposite. (check) |
| inventor_country | US | Filter to at least one US inventor. |  | What JTH uses to separate domestic vs foreign patents. TFK and MNOT restrics to at least one US domiciled inventor. |
| inventor_id |  |  |  | JTH suggests in comment to TF to remove inventor self-cites. MNOT does so. |
| citation_category | TODO: restrict to "cited by applicant". |  |  | Check Thompson (2006) for justification. Other papers dont seem to bother with this, only briefly mention. |

Data from the USPTO API. The idea for sample construction right now is:

1. Pick sample of patents (e.g., university asignees) plus originating year, mainly to make it computationally viable.
2. Randomly select inventor of patent and assign geographic location (alternatively, use JTH method).
3. Match inventor location to feature in US map.
4. Restric the sample (e.g., remove no geographic data, self-cites, no assignee)
5. Find nearest patent by semantic similarity between abstracts within a data range.
6. Find distances between controls and citing patents to originating ones.

also see: <https://onlinelibrary.wiley.com/doi/10.1111/jems.12262>

Useful data dictionary from: <https://patentsview.org/download/data-download-dictionary>

assignee_type = classification of assignee (1 - Unassigned, 2 - US Company or Corporation, 3 - Foreign Company or Corporation, 4 - US Individual, 5 - Foreign Individual, 6 - US Federal Government, 7 - Foreign Government, 8 - US County Government, 9 - US State Government. Note: A "1" appearing before any of these codes signifies part interest

## References

Interesting papers that might be useful:

<https://academic.oup.com/qje/article/134/2/647/5218522#133115040>

<https://eml.berkeley.edu/~pkline/papers/KPWZ_QJE_2019.pdf>

<https://www.uspto.gov/sites/default/files/documents/oce-women-patentees-report.pdf>

<https://www.journals.uchicago.edu/doi/full/10.1086/723636>

Keeping in EndNote for now.
