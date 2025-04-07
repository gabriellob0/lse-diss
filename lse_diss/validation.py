from pathlib import Path

import polars as pl

data_path = Path("data")
raw_patents_path = data_path / "raw" / "patents"

# TODO:
# remove missing abstracts

# NOTE:
# inventor sequence should not skip in theory, but it will since I remove foreign ones
# still worth just checking what it looks like
# patent_id, patent_date, patent_abstract, inventor_id, inventor_location_id,
# inventor_sequence, assignee_id, and assignee location_id should never be missing


def count_null(path):
    df = pl.scan_parquet(path)

    nulls_count = df.null_count().collect()
    null_columns = nulls_count.select(
        col for col in nulls_count.iter_columns() if col.item(0) > 0
    )

    print("null values: ", null_columns)


def count_other(path):
    df = pl.scan_parquet(path)

    missing_values = ["null", "na", "n/a", "none", "nan", "missing", "unknown"]
    missing_columns = (
        df.select(["patent_id", "patent_abstract"])
        .drop_nulls()
        .slice(0, 3)
        .with_columns(pl.col("*").cast(pl.Utf8).str.to_lowercase())
        .filter(pl.any_horizontal(pl.col("*").is_in(missing_values)))
        .collect_schema()
    )

    print("missing values: ", missing_columns)


def check_dates(path):
    date_format = r"^\d{4}-\d{2}-\d{2}$"

    df = pl.scan_parquet(path)

    dates = (
        df.select(["patent_date", "patent_earliest_application_date"])
        .filter(~pl.any_horizontal(pl.col("*").str.contains(date_format)))
        .collect()
    )

    print(dates)


def check_range(path):
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

    print(dates)


def check_uniqueness(path):
    df = pl.scan_parquet(path)

    all_size = df.select(pl.len()).collect()

    unique_size = (
        df.unique(
            ["patent_id", "inventor_id", "inventor_location_id", "inventor_sequence"]
        )
        .select(pl.len())
        .collect()
    )

    print("unique? ", all_size == unique_size)


count_null("data/raw/patents")
# count_other("data/raw/patents")
check_dates("data/raw/patents")
check_uniqueness("data/raw/patents")
check_range("data/raw/patents")
