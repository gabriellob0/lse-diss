# lse-diss

Dissertation for my MSc in Economics at the LSE.

## Overview

I want to analyse the extent of geographic concentration in patent citations, using non-citing patent controls. The key idea is to improve previous estimates by matching controls using embedded patent abstracts. I might also check how this has changed over time, previous papers were mainly limitted to the NBER patent database. Patent controls seem to have been introduced by Jaffe et al., and they should have the same "technological and temporal distribution" as citing patents.

## Roadmap

I should figure out data I want from the API and what data I want bulk. Probably patent data and abstracts from bulk. Unify the code in Python since polars can process the large dataset better AFAIK.

After that, I can either scale the thing and do the test or see if I can find better address data.

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

### Sample Construction Table

| API Field                            | Values                                                                  | Notes                                                                   | Source                                                             | Literature                                                                                                                  |
|--------------------------------------|-------------------------------------------------------------------------|-------------------------------------------------------------------------|--------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| assignee_type                        | I am using "2" and "3" for now?, which means a US or foreign company.    | 4 and 5 includes individuals                                            | <https://patentsview.org/download/data-download-dictionary>          | JTH argues this information is not relevant. TFK also removes individual assignees. MNOT also restricts to non-gov patents. |
| assignee_country                     | I restrict to US?                                                       |                                                                         |                                                                    | MNOT restricts to the US.                                                                                                   |
| patent_num_times_cited_by_us_patents | Set to greater than one, if not it won't ever be an originating patent. |                                                                         |                                                                    |                                                                                                                             |
| patent_type                          | Set to "utility".                                                       | This excludes                                                           | <https://www.uspto.gov/web/offices/ac/ido/oeip/taf/data/patdesc.htm> |                                                                                                                             |
| patent_date                          |                                                                         | Grant date.                                                             |                                                                    | JTH uses grant date to match controls. TFK does the opposite. (check)                                                       |
| assignee_id                          | TODO: remove self-citations                                             | Find from the URL in assignees.assignee                                 |                                                                    | JTH removes self-citations                                                                                                  |
| inventor_sequence                    |                                                                         | Order inventors appear in file. Might be useful for selecting location. |                                                                    |                                                                                                                             |
| patent_earliest_application_date     |                                                                         | Might be useful to set baseline originating year.                       |                                                                    | I think JTH uses this for originating years. TFK does the opposite. (check)                                                 |
| inventor_country                     | NA                                                                      | Cant filter for all US inventors unless negate all other countries.     |                                                                    | What JTH uses to separate domestic vs foreign patents. TFK restrics to at least one US domiciled inventor.                  |
| inventor_id                          |                                                                         |                                                                         |                                                                    | JTH suggests in comment to TF to remove inventor self-cites.                                                                |
| citation_category                    | TODO: restrict to "cited by applicant"                                  |                                                                         |                                                                    | Check Thompson (2006) for justification. Other papers dont seem to bother with this, only briefly mention.                  |

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
