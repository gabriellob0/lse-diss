from lse_diss.features import clean_patents, trim_abstracts, clean_citations, make_treated

clean_patents()
trim_abstracts()

# I need to check clean citations better and do some robustness tests with the filtering in make_treated
clean_citations()

# TODO: probably treat patent locations separately and just join at the very end

from pathlib import Path

import polars as pl

from lse_diss.features import make_treated

df = make_treated()
df.collect()


def make_control(
    treated,
    patents_path=Path("data", "processed", "patents"),
    citations_path=Path("data", "interim", "citations.parquet"),
):
    patents = pl.scan_parquet(patents_path).filter(
        pl.col("patent_date").is_between(pl.date(2000, 1, 1), pl.date(2005, 1, 1))
    )

    all_controls = (
        patents
        .group_by("patent")
        .agg(pl.col("assignee_id"), pl.col("inventor_id"))
    )

    citations = pl.scan_parquet(citations_path)

    originating_patents = (
        treated.select("patent_id")
        .unique()
        .slice(0, 100)
        .join(patents, on="patent_id", validate="1:m")
        .group_by("patent_id")
        .agg(pl.col("assignee_id"), pl.col("inventor_id"))
        .join(citations, left_on="patent_id", right_on="originating_patent_id")
        .group_by(["patent_id", "assignee_id", "inventor_id"])
        .agg(pl.col("citing_patent_id"))
    )

    potential_controls = (
        treated.join(originating_patents, on="patent_id", validate="m:1")
        .select(
            [
                "citing_patent_id",
                "patent_earliest_application_date_citing",
                "patent_id",
                "assignee_id",
                "inventor_id",
                "citing_patent_id_right",
            ]
        )
        .rename(
            {
                "patent_earliest_application_date_citing": "citing_application_date",
                "patent_id": "originating_patent_id",
                "assignee_id": "originating_assignee_id",
                "inventor_id": "originating_inventor_id",
                "citing_patent_id_right": "originating_citing_ids",
            }
        )
        .join()
        .collect()
    )

    return potential_controls


make_control(df)

""" 
def make_control(
    treated,
    patents_path=Path("data", "processed", "patents"),
    citations_path=Path("data", "interim", "citations.parquet"),
):
    originating = treated.select("patent_id").unique().slice(0, 100)

    patents = pl.scan_parquet(patents_path)

    all_ids = (
        patents
        .filter(pl.col("patent_date").is_between(pl.date(2000, 1, 1), pl.date(2005, 1, 1)))
        .select("patent_id")
        .unique()
    )

    citations = (
        pl.scan_parquet(citations_path)
        .join(originating, left_on="originating_patent_id", right_on="patent_id")
        .rename({"originating_patent_id": "patent_id", "citing_patent_id": "patent_id_right"})
        .select(["patent_id", "patent_id_right"])
    )

    controls = (
        originating
        .join(all_ids, how="cross")
        .filter("patent_id" != "patent_id_right")
        .join(citations, on = ["patent_id", "patent_id_right"], how="anti")
        .collect_schema()
    )

    return controls
 """

# make_control(df)
