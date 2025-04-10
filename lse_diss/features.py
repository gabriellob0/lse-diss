from pathlib import Path

import polars as pl


def make_locations(
    patents_path=Path("data", "raw", "patents"),
    save_path=Path("data", "interim", "locations.parquet"),
):
    patents = (
        pl.scan_parquet(patents_path)
        .filter(inventor_country="US")
        .select(
            ["patent_id", "inventor_id", "inventor_sequence", "inventor_location_id"]
        )
        # NOTE: this remove duplicate inventors with different sequence values
        .sort(["patent_id", "inventor_sequence"])
        .unique(["patent_id", "inventor_id", "inventor_location_id"], keep="first")
    )

    locations = (
        patents.with_columns(
            pl.len().over("patent_id", "inventor_location_id").alias("count")
        )
        # NOTE: location rule 1
        .filter(pl.col("count").eq(pl.max("count").over("patent_id")))
        # NOTE: location rule 2
        .filter(
            pl.col("inventor_sequence").eq(
                pl.min("inventor_sequence").over("patent_id")
            )
        )
        .select(["patent_id", "inventor_location_id"])
        .rename({"inventor_location_id": "patent_location_id"})
    )

    locations.sink_parquet(save_path, mkdir=True)


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


def make_originating(patents_path=Path("data", "interim", "patents"), base_year=2005):
    start_date = pl.date(base_year, 1, 1)
    end_date = pl.date(base_year, 2, 1)

    patents = (
        pl.scan_parquet(patents_path)
        .group_by("patent_id", "assignee_id", "grant_date", "application_date")
        .agg(pl.col("inventor_id"))
        .with_columns(
            pl.when(pl.col("grant_date").is_between(start_date, end_date))
            .then(1)
            .otherwise(0)
            .alias("originating_dummy")
        )
    )

    return patents


def make_treated(
    df,
    citations_path=Path("data", "interim", "citations.parquet"),
    base_year=2005,
    duration=1,
):
    start_date = pl.date(base_year, 1, 1)
    end_date = pl.date(base_year + duration, 1, 1)

    patents = df.filter(pl.col("grant_date").is_between(start_date, end_date)).select(
        "patent_id", "assignee_id", "inventor_id"
    )

    citations = pl.scan_parquet(citations_path).select(
        ["cited_patent_id", "citing_patent_id"]
    )

    pairs = (
        df.filter(originating_dummy=1)
        .select("patent_id", "assignee_id", "inventor_id")
        .rename({"patent_id": "cited_patent_id"})
        .join(citations, on="cited_patent_id", validate="1:m")
        .join(patents, left_on="citing_patent_id", right_on="patent_id")
        .filter(
            pl.col("assignee_id") != pl.col("assignee_id_right"),
            pl.col("inventor_id")
            .list.set_intersection("inventor_id_right")
            .list.len()
            .eq(0),
        )
        .select("citing_patent_id", "cited_patent_id")
    )

    return pairs


def make_control(
    patents,
    treatment_pairs,
    citation_path=Path("data", "interim", "citations.parquet"),
    base_year=2005,
    duration=3,
):
    start_date = pl.date(base_year, 1, 1)
    end_date = pl.date(base_year + duration, 1, 1)

    citations = pl.scan_parquet(citation_path).rename(
        {"citing_patent_id": "control_id"}
    )

    all_ids = patents.filter(
        pl.col("grant_date").is_between(start_date, end_date)
    ).select(pl.exclude(["grant_date", "originating_dummy"]))

    cross_join = (
        treatment_pairs.join(
            all_ids.select(["patent_id", "application_date"]),
            left_on="citing_patent_id",
            right_on="patent_id",
        )
        .join(all_ids.select(pl.col("patent_id").alias("control_id")), how="cross")
        .filter(
            pl.col("citing_patent_id") != pl.col("control_id"),
            pl.col("cited_patent_id") != pl.col("control_id"),
        )
    )

    anti_join = cross_join.join(
        citations, on=["cited_patent_id", "control_id"], how="anti"
    )

    return anti_join.select(pl.len()).collect()
