from pathlib import Path

import polars as pl


def validate_patents(path):
    # TODO: validate missing and patent_date formatting
    df = pl.scan_parquet(path, include_file_paths="file_name")

    dates = (
        df.select("patent_date", "patent_id", "file_name")
        .unique()
        .group_by(pl.col("file_name"))
        .agg(
            pl.len(),
            pl.min("patent_date").alias("actual_min"),
            pl.max("patent_date").alias("actual_max"),
        )
        .with_columns(
            pl.col("file_name")
            .str.extract(r"(\d{4}-\d{2}-\d{2})_to_(\d{4}-\d{2}-\d{2})", 1)
            .alias("expected_min"),
            pl.col("file_name")
            .str.extract(r"(\d{4}-\d{2}-\d{2})_to_(\d{4}-\d{2}-\d{2})", 2)
            .alias("expected_max"),
        )
        .with_columns(
            pl.col(
                ["actual_min", "actual_max", "expected_min", "expected_max"]
            ).str.to_date()
        )
        .with_columns(
            pl.col("expected_min").le(pl.col("actual_min")).alias("min_test"),
            pl.col("expected_max").ge(pl.col("actual_max")).alias("max_test"),
        )
        .collect()
    )

    print(
        "date check: ",
        all([all(dates.get_column("min_test")), all(dates.get_column("max_test"))]),
    )

    uniqueness = df.select(
        "patent_id", "inventor_id", "inventor_location_id", "inventor_sequence"
    ).collect()
    # NOTE: found a few duplicated inventors because of different locations for the same person
    # the rest is explained by inventor sequence
    duplicated = len(uniqueness.filter(uniqueness.is_duplicated())) == 0
    print("uniqueness check: ", duplicated)


def clean_patents(raw_path, clean_path):
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
            .with_columns(
                pl.col(
                    ["patent_date", "patent_earliest_application_date"]
                ).str.to_date()
            )
            .filter(pl.col("patent_date").is_between(start_date, end_date))
        )

        deduplicated_patents = (
            raw_patents
            .sort(
                ["patent_id", "patent_date", "inventor_sequence"]
            )
            .unique(["patent_id", "inventor_id", "inventor_location_id"], keep="first")
        )

        inventor_locations = (
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
            deduplicated_patents
            .join(
                inventor_locations, on="patent_id", how="left", validate="m:1"
            )
            .sink_parquet(path)
        )


data_path = Path("data")
raw_patents_path = data_path / "raw" / "patents"
clean_patents_path = data_path / "processed" / "patents"
citations_path = data_path / "raw" / "bulk_downloads" / "g_us_patent_citation.parquet"

validate_patents(raw_patents_path)
clean_patents(raw_patents_path, clean_patents_path)


# # path for bulk downloaded data
# base_path = Path("data", "raw", "bulk_downloads")
# patents_path = base_path / "g_patent.parquet"
# assignee_path = base_path / "g_assignee_disambiguated.parquet"
# locations_path = base_path / "g_locations"

# pl.scan_parquet(patents_path).collect_schema()
# pl.scan_parquet(assignee_path).collect_schema()

# assignees = (
#     pl.scan_parquet(assignee_path)
#     .with_columns(pl.len().over("patent_id").alias("assignee_count"))
#     .filter(
#         pl.col("assignee_count") == 1,
#         pl.col("assignee_type") == "2"
#     )
# )

# locations = (

# )

# q = (
#     pl.scan_parquet(patents_path)
#     .with_columns(pl.col("patent_date").str.to_date())
#     .filter(
#         pl.col("patent_type") == "utility",
#         pl.col("patent_date").is_between(pl.date(2000, 1, 1), pl.date(2000, 12, 31)),
#         pl.col("withdrawn") == 0
#     )
#     .join(assignees, on="patent_id", how="inner")
#     .select(["patent_id", "patent_title", "assignee_id", "location_id"])
# )

# df = q.collect()

# df.shape
# df.schema
# df.head(5)

# df.shape[0] == df.unique().shape[0]
