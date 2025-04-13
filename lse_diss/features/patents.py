from pathlib import Path

import polars as pl


def load_patents(path=Path("data", "raw", "patents")):
    patents = pl.scan_parquet(path)

    not_missing = (
        patents.with_columns(
            pl.when(pl.any_horizontal(pl.col("*").is_null()))
            .then(1)
            .otherwise(0)
            .alias("missing")
        )
        .group_by("patent_id")
        .agg(pl.sum("missing"))
        .filter(missing=0)
        .join(patents, on="patent_id", how="left", validate="1:m")
    )

    renamed = (
        not_missing.select(
            pl.exclude(
                [
                    "inventor_location_id",
                    "inventor_sequence",
                    "inventor_country",
                    "assignee_organization",
                    "assignee_location_id",
                    "missing",
                ]
            )
        )
        .rename(
            {
                "patent_date": "grant_date",
                "patent_earliest_application_date": "application_date",
            }
        )
        .with_columns(pl.col(["grant_date", "application_date"]).str.to_date())
    )

    # NOTE: there should be only single assignee patents, this has been checked
    deduplicated = renamed.unique(["patent_id", "inventor_id"])

    return deduplicated


def trim_abstracts(df):
    abstracts = (
        df.select("patent_id", "patent_abstract")
        .unique()
        .with_columns(pl.col("patent_abstract").str.len_chars().alias("n_chars"))
        # NOTE: abstracts that are too small are not informative and will not have matches, too big might exceed token limit for embedding
        .filter(
            pl.col("n_chars").is_between(
                pl.quantile("n_chars", 0.01), pl.quantile("n_chars", 0.99)
            )
        )
    )

    patents = abstracts.select("patent_id").join(
        df, on="patent_id", how="left", validate="1:m"
    )

    return patents


def save_patents(df, path=Path("data", "interim", "patents")):
    path.mkdir(parents=True, exist_ok=True)

    df.sink_parquet(
        pl.PartitionMaxSize(path / "patent_{part}.parquet", max_size=512_000)
    )


def filter_citations(
    patents_path=Path("data", "interim", "patents"),
    citations_path=Path(
        "data", "raw", "bulk_downloads", "g_us_patent_citation.parquet"
    ),
    save_path=Path("data", "interim", "citations.parquet"),
):
    patents = pl.scan_parquet(patents_path).select("patent_id").unique()

    citations = (
        pl.scan_parquet(citations_path)
        .join(patents, on="patent_id")
        .join(patents, left_on="citation_patent_id", right_on="patent_id")
        # NOTE: other categories most likely do not reflect spillovers
        # TODO: check again for empty strings
        .filter(
            pl.col("citation_category").is_in(
                ["cite by examiner", "cited by applicant", "cited by other"]
            )
        )
        .select("patent_id", "citation_patent_id", "citation_category")
        .rename(
            {"patent_id": "citing_patent_id", "citation_patent_id": "cited_patent_id"}
        )
        .unique()
    )

    citations.sink_parquet(save_path)
