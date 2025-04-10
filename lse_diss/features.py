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


def load_patents(patents_path=Path("data", "raw", "patents")):
    patents = pl.scan_parquet(patents_path)

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


def clean_citations(
    patents_path=Path("data", "processed", "patents"),
    raw_path=Path("data", "raw", "bulk_downloads", "g_us_patent_citation.parquet"),
    clean_path=Path("data", "interim"),
):
    clean_path.mkdir(parents=True, exist_ok=True)
    file_path = clean_path / "citations.parquet"

    patents = (
        pl.scan_parquet(patents_path)
        .select(["patent_id", "patent_earliest_application_date"])
        .unique()
    )

    citations = (
        pl.scan_parquet(raw_path)
        .select(["patent_id", "citation_patent_id", "citation_category"])
        .join(patents, on="patent_id", how="inner")
        .join(patents, left_on="citation_patent_id", right_on="patent_id", how="inner")
        .rename(
            {
                "citation_patent_id": "originating_patent_id",
                "patent_id": "citing_patent_id",
                "patent_earliest_application_date": "citing_application_date",
            }
        )
        .select(
            ["originating_patent_id", "citing_patent_id", "citing_application_date"]
        )
    )

    citations.sink_parquet(file_path)


def make_treated(
    patents_path=Path("data", "processed", "patents"),
    citation_path=Path("data", "interim", "citations.parquet"),
    year=2000,
    duration=5,
):
    start_date = pl.date(year, 1, 1)
    originating_end_date = pl.date(year, 2, 1)
    treated_end_date = pl.date(year + duration, 1, 1)

    patents = (
        pl.scan_parquet(patents_path)
        .group_by("patent_id")
        .agg(
            pl.col("inventor_id"),
            pl.col("assignee_id"),
            pl.first("patent_date"),
            pl.first("patent_earliest_application_date"),
            pl.first("patent_location_id"),
        )
    )

    citations = pl.scan_parquet(citation_path).select(
        ["originating_patent_id", "citing_patent_id"]
    )

    originating_set = patents.filter(
        pl.col("patent_date").is_between(start_date, originating_end_date)
    ).join(
        citations,
        left_on="patent_id",
        right_on="originating_patent_id",
        validate="1:m",
    )

    pairs = (
        originating_set.join(
            patents,
            left_on="citing_patent_id",
            right_on="patent_id",
            validate="m:1",
            suffix="_citing",
        )
        .filter(
            pl.col("patent_date_citing").is_between(start_date, treated_end_date),
            pl.col("inventor_id")
            .list.set_intersection("inventor_id_citing")
            .list.len()
            .eq(0),
            pl.col("assignee_id")
            .list.set_intersection("assignee_id_citing")
            .list.len()
            .eq(0),
            # TODO: there is something weird going on here, no pairs within 10 years distance
            # example, 7162303 should be here (it was removed because it was cited by other)
            # TODO: tally citations by citation_category
        )
        .select(
            [
                "patent_id",
                "patent_location_id",
                "citing_patent_id",
                "patent_earliest_application_date_citing",
                "patent_location_id_citing",
            ]
        )
    )

    return pairs


def make_control(df):
    print("a")
