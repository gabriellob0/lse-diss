from pathlib import Path

import polars as pl
from geopy import distance


def make_locations(
    patents_path=Path("data", "raw", "patents"),
    locations_path=Path(
        "data", "raw", "bulk_downloads", "g_location_disambiguated.parquet"
    ),
    save_path=Path("data", "interim", "locations.parquet"),
):
    locations = pl.scan_parquet(locations_path).select(
        ["location_id", "latitude", "longitude"]
    )

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

    patent_locations = (
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
        .rename({"inventor_location_id": "location_id"})
    )

    joined_locations = patent_locations.join(
        locations, on="location_id", validate="m:1"
    )

    joined_locations.sink_parquet(save_path, mkdir=True)


def make_distances(
    controls_path=Path("data", "processed", "controls.parquet"),
    locations_path=Path("data", "interim", "locations.parquet"),
    save_path=Path("data", "processed", "distances.parquet"),
):
    controls = pl.scan_parquet(controls_path)
    locations = pl.scan_parquet(locations_path)

    matched_patents = (
        controls.unpivot(
            pl.col(["citing_patent_id", "control_patent_id"]),
            index=pl.col("cited_patent_id"),
        )
        .with_columns(
            pl.when(pl.col("variable") == "citing_patent_id")
            .then(1)
            .otherwise(0)
            .alias("treatment_dummy")
        )
        .join(
            locations, left_on="cited_patent_id", right_on="patent_id", validate="m:1"
        )
        .join(locations, left_on="value", right_on="patent_id", validate="m:1")
        .rename(
            {
                "cited_patent_id": "parent_patent_id",
                "value": "child_patent_id",
                "location_id": "parent_location_id",
                "location_id_right": "child_location_id",
                "latitude": "parent_latitude",
                "longitude": "parent_longitude",
                "latitude_right": "child_latitude",
                "longitude_right": "child_longitude",
            }
        )
        .select(
            pl.col("parent_patent_id"),
            pl.concat_list("parent_latitude", "parent_longitude").alias(
                "parent_location"
            ),
            pl.col("child_patent_id"),
            pl.concat_list("child_latitude", "child_longitude").alias("child_location"),
            pl.col("treatment_dummy"),
        )
        .collect()
    )

    distances = []

    for row in matched_patents.iter_rows():
        parent = tuple(row[1])
        child = tuple(row[3])
        dist = distance.distance(parent, child).km
        distances.append(dist)

    patents_with_distances = matched_patents.with_columns(
        distance=pl.Series(distances)
    ).select(["parent_patent_id", "child_patent_id", "treatment_dummy", "distance"])

    patents_with_distances.write_parquet(save_path)
