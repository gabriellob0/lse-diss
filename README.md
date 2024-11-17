# lse-diss
Dissertation for the MSc in Economics at the LSE

## Overview

IDEA:
1. Download public patent data (possibly for a specific sector, most likely US only)
2. Match names in patents to different ethnicities, I believe there are useful datasets for this freely available
3. Extract some characteristic of these patents from abstract (e.g., skills)
4. Match demographic characteristic from ethnicity to these patents

For 3 a 4, two ideas:
* Health inventions and prevalence of disease it cures
* Skills used by patent (e.g., in software?) and prevalence of skills in other data (e.g., IPUMS)

IDEA:
* Fixed effects if inventors with multiple patents

## Roadmap

Next, probably play with the API data and extract some stuff with NLP.

## Data

Currently, trying data from here: https://developer.uspto.gov/product/patent-assignment-economics-data-stata-dta-and-ms-excel-csv#product-files

also see: https://onlinelibrary.wiley.com/doi/10.1111/jems.12262

This does not seem the right one, patent claim might be better: https://www.uspto.gov/ip-policy/economic-research/research-datasets/patent-claims-research-dataset

I managed to get the API to work, it seems like the way forward. I will extract patents according to some criteria and I think maybe have a row per inventor-patent pair.

## References

Interesting papers that might be useful:

https://academic.oup.com/qje/article/134/2/647/5218522#133115040

https://eml.berkeley.edu/~pkline/papers/KPWZ_QJE_2019.pdf

https://www.uspto.gov/sites/default/files/documents/oce-women-patentees-report.pdf

https://www.journals.uchicago.edu/doi/full/10.1086/723636

