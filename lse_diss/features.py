from pathlib import Path

import polars as pl


def clean_patents(
    raw_path=Path("data", "raw", "patents"),
    clean_path=Path("data", "interim", "patents"),
):
    years = [
        "2000-01-01_to_2009-12-31",
        "2010-01-01_to_2019-12-31",
        "2020-01-01_to_2025-01-01",
    ]

    clean_path.mkdir(parents=True, exist_ok=True)

    for year in years:
        print("doing ", year)

        path = clean_path / (year + ".parquet")

        start_date, end_date = pl.Series(year.split("_to_")).str.to_date()

        raw_patents = (
            pl.scan_parquet(raw_path, low_memory=True)
            .drop_nulls("patent_abstract")
            .with_columns(
                pl.col(
                    ["patent_date", "patent_earliest_application_date"]
                ).str.to_date()
            )
            .filter(pl.col("patent_date").is_between(start_date, end_date))
        )

        deduplicated_patents = raw_patents.sort(
            ["patent_id", "patent_date", "inventor_sequence"]
        ).unique(["patent_id", "inventor_id", "inventor_location_id"], keep="first")

        patent_locations = (
            deduplicated_patents.with_columns(
                pl.len().over("patent_id", "inventor_location_id").alias("count")
            )
            # rule 1
            .filter(pl.col("count") == pl.max("count").over("patent_id"))
            # rule 2
            .filter(
                pl.col("inventor_sequence")
                == pl.min("inventor_sequence").over("patent_id")
            )
            .select("patent_id", "inventor_location_id")
            .rename({"inventor_location_id": "patent_location_id"})
        )

        (
            deduplicated_patents.join(
                patent_locations, on="patent_id", how="left", validate="m:1"
            ).sink_parquet(path)
        )


def trim_abstracts(
    raw_path=Path("data", "interim", "patents"),
    clean_path=Path("data", "processed", "patents"),
):
    df = pl.scan_parquet(raw_path, include_file_paths="file_name")

    clean_path.mkdir(parents=True, exist_ok=True)

    quantiles = (
        df.unique(["patent_id", "patent_abstract"])
        .with_columns(pl.col("patent_abstract").str.len_chars().alias("n_chars"))
        .select(
            pl.quantile("n_chars", 0.01).alias("q_low"),
            pl.quantile("n_chars", 0.99).alias("q_high"),
        )
        .collect()
    )

    q_low = quantiles.item(0, 0)
    q_high = quantiles.item(0, 1)

    for p in raw_path.glob("*"):
        stem = p.stem
        file_path = clean_path / p.name
        print("doing: ", file_path)

        abstracts = (
            df.filter(pl.col("file_name").str.contains(stem))
            .filter(pl.col("patent_abstract").str.len_chars().is_between(q_low, q_high))
            .select(
                [
                    "patent_id",
                    "patent_date",
                    "patent_abstract",
                    "patent_earliest_application_date",
                    "inventor_id",
                    "assignee_id",
                    "patent_location_id",
                ]
            )
        )

        abstracts.sink_parquet(file_path)


def create_treatment(patents_path, citations_path):
    # TODO: check data availability on citation_category for year before 2002

    patents = (
        pl.scan_parquet(patents_path)
        .select("patent_id", "patent_date", "inventor_id", "assignee_id")
        .group_by("patent_id")
        .agg(pl.col("inventor_id"), pl.col("assignee_id"), pl.first("patent_date"))
    )

    originating = patents.filter(
        pl.col("patent_date").is_between(pl.date(2000, 1, 1), pl.date(2000, 2, 1))
    )
    originating_ids = originating.select("patent_id").unique().collect().to_series()

    citations = (
        pl.scan_parquet(citations_path)
        .filter(
            pl.col("citation_patent_id").is_in(originating_ids)  # ,
            # citation_category = "cited by applicant"
        )
        .select("citation_patent_id", "patent_id", "citation_category")
        .rename(
            {
                "citation_patent_id": "originating_patent_id",
                "patent_id": "citing_patent_id",
            }
        )
        .unique()
    )

    pairs = (
        originating.join(
            citations,
            left_on="patent_id",
            right_on="originating_patent_id",
            validate="1:m",
        )
        .join(
            patents, left_on="citing_patent_id", right_on="patent_id", suffix="_citing"
        )
        .filter(
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
            pl.col("patent_date_citing").is_between(
                pl.date(2000, 1, 1), pl.date(2005, 1, 1)
            ),
        )
    )

    pairs.collect()


# data_path = Path("data")
# raw_patents_path = data_path / "raw" / "patents"
# clean_patents_path = data_path / "processed" / "patents"
# citations_path = data_path / "raw" / "bulk_downloads" / "g_us_patent_citation.parquet"

# clean_patents(raw_patents_path, clean_patents_path)
