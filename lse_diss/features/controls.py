from math import ceil
from pathlib import Path

import polars as pl
from tqdm import tqdm


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
    duration=3,
):
    start_date = pl.date(base_year, 1, 1)
    end_date = pl.date(base_year + duration, 1, 1)

    # NOTE: potential treatment members
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
        # NOTE: removes self-cites
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


def make_controls(
    patents,
    treated,
    base_year=2005,
    duration=3,
    search_range=30,
):
    start_date = pl.date(base_year, 1, 1)
    end_date = pl.date(base_year + duration, 1, 1)

    potential_controls = (
        patents.filter(pl.col("grant_date").is_between(start_date, end_date))
        .select(pl.exclude(["grant_date", "originating_dummy"]))
        .select(pl.all().name.prefix("control_"))
    )

    citing = (
        treated.join(
            patents.select(
                pl.col(["patent_id", "application_date"]).name.prefix("citing_")
            ),
            on="citing_patent_id",
        )
        .with_columns(
            (pl.col("citing_application_date") - pl.duration(days=search_range)).alias(
                "min_date"
            ),
            (pl.col("citing_application_date") + pl.duration(days=search_range)).alias(
                "max_date"
            ),
        )
        .select(pl.exclude("citing_application_date"))
    )

    cited = citing.join(
        patents.select(
            pl.col(["patent_id", "assignee_id", "inventor_id"]).name.prefix("cited_")
        ),
        on="cited_patent_id",
    )

    joined = cited.join_where(
        potential_controls,
        pl.col("control_application_date").is_between(
            pl.col("min_date"), pl.col("max_date")
        ),
        pl.col("citing_patent_id") != pl.col("control_patent_id"),
        pl.col("cited_patent_id") != pl.col("control_patent_id"),
        pl.col("cited_assignee_id") != pl.col("control_assignee_id"),
    )

    # filters just to be safe
    result = (
        joined.filter(
            pl.col("control_application_date").is_between(
                pl.col("min_date"), pl.col("max_date")
            ),
            pl.col("citing_patent_id") != pl.col("control_patent_id"),
            pl.col("cited_patent_id") != pl.col("control_patent_id"),
            pl.col("cited_assignee_id") != pl.col("control_assignee_id"),
            pl.col("cited_inventor_id")
            .list.set_intersection(pl.col("control_inventor_id"))
            .list.len()
            .eq(0),
        )
        .select(["citing_patent_id", "cited_patent_id", "control_patent_id"])
        .unique()
    )

    return result


def remove_cited(df, citations_path=Path("data", "interim", "citations.parquet")):
    citations = pl.scan_parquet(citations_path).select(
        pl.col("cited_patent_id"), pl.col("citing_patent_id").alias("control_patent_id")
    )

    controls = df.join(
        citations, on=["cited_patent_id", "control_patent_id"], how="anti"
    )

    return controls


def save_controls(
    patents,
    pairs,
    duration=3,
    search_range=30,
    path=Path("data", "interim", "controls"),
    batch_size=500,
):
    path.mkdir(parents=True, exist_ok=True)

    total_pairs = pairs.select(pl.len()).collect().item(0, 0)
    total_batches = ceil(total_pairs / batch_size)

    for i in tqdm(range(total_batches), desc="Processing batches", unit="batch"):
        file_name = path / (f"controls_{i}" + ".parquet")

        start = i * batch_size
        length = min(batch_size, total_pairs - start)

        sliced_pairs = pairs.slice(start, length)
        potential_controls = make_controls(
            patents, sliced_pairs, duration=duration, search_range=search_range
        )
        controls = remove_cited(potential_controls)
        controls.sink_parquet(file_name)
