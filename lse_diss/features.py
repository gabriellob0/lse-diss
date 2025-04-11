from math import ceil
from pathlib import Path

import polars as pl
from tqdm import tqdm


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
    duration=2,
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
    duration=2,
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

    # TODO: consider non-equi join, but the engine might do it for me
    cross_join = (
        cited.join(potential_controls, how="cross")
        .filter(
            pl.col("citing_patent_id") != pl.col("control_patent_id"),
            pl.col("cited_patent_id") != pl.col("control_patent_id"),
            pl.col("cited_assignee_id") != pl.col("control_assignee_id"),
            pl.col("control_application_date").is_between(
                pl.col("min_date"), pl.col("max_date")
            ),
            pl.col("cited_inventor_id")
            .list.set_intersection("control_inventor_id")
            .list.len()
            .eq(0),
        )
        .select(["citing_patent_id", "cited_patent_id", "control_patent_id"])
    )

    return cross_join


def remove_cited(df, citations_path=Path("data", "interim", "citations.parquet")):
    citations = pl.scan_parquet(citations_path).select(
        pl.col("cited_patent_id"), pl.col("citing_patent_id").alias("control_patent_id")
    )

    controls = df.join(
        citations, on=["cited_patent_id", "control_patent_id"], how="anti"
    )

    return controls


def save_controls(
    patents, pairs, duration=3, path=Path("data", "interim", "controls"), batch_size=25
):
    path.mkdir(parents=True, exist_ok=True)

    total_rows = ceil(pairs.select(pl.len()).collect().item(0, 0) / batch_size)

    for i in tqdm(range(total_rows), desc="Processing batches", unit="batch"):
        file_name = path / (f"controls_{i}" + ".parquet")

        start = i * batch_size
        end = min((i + 1) * batch_size, total_rows)

        sliced_pairs = pairs.slice(start, end)
        potential_controls = make_controls(patents, sliced_pairs, duration=duration)
        controls = remove_cited(potential_controls)
        controls.sink_parquet(file_name)


def filter_abstracts(
        patents_path=Path("data", "interim", "patents"),
        controls_path=Path("data", "interim", "controls"),
        save_path = Path("data", "interim", "abstracts.parquet")
):
    patents = pl.scan_parquet(patents_path).select("patent_id", "patent_abstract").unique()

    controls = (
        pl.scan_parquet(controls_path)
        .select("citing_patent_id", "control_patent_id")
        .unpivot()
        .select("value")
        .unique()
    )

    abstracts = (
        patents
        .join(controls, left_on="patent_id", right_on="value", how="inner")
        .with_row_index()
    )

    abstracts.sink_parquet(save_path)
