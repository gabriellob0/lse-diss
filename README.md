# lse-diss
Dissertation for the MSc in Economics at the LSE

## Overview

Analyse how localised knowledge spillovers are and how much this has changed (e.g., pre and post pandemic).

## Data

Data from the USPTO API. The idea for sample construction right now is:
1. Pick sample of patents (e.g., university asignees) plus originating year, mainly to make it computationally viable.
2. Randomly select inventor of patent and assign geographic location (alternatively, use JTH method).
3. Match inventor location to feature in US map.
4. Restric the sample (e.g., remove no geographic data, self-cites, no assignee)
5. Find nearest patent by semantic similarity between abstracts within a data range.
6. Find distances between controls and citing patents to originating ones.

## References

Keeping in EndNote for now.
