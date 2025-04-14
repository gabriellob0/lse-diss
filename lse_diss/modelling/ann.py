from math import ceil
from pathlib import Path

import polars as pl
from voyager import Index, Space, StorageDataType


def create_index(
    embeddings_path=Path("data", "processed", "embeddings"),
    save_path=Path("data", "interim"),
):
    file_path = str(save_path / "index.voy")

    df = pl.scan_parquet(embeddings_path).collect()
    embeddings = df.get_column("embedding").to_numpy()

    dimension = embeddings.shape[1]
    index = Index(
        Space.Cosine, num_dimensions=dimension, storage_data_type=StorageDataType.E4M3
    )
    index.add_items(embeddings)

    index.save(str(file_path))


def open_index(path=Path("data", "interim", "index.voy")):
    path_str = str(path)
    with open(path_str, "rb") as f:
        index = Index.load(f)
    return index


def match_controls(
    voyager_index,
    embeddings_path=Path("data", "processed", "embeddings"),
    controls_path=Path("data", "interim", "controls"),
    save_path=Path("data", "processed", "controls.parquet"),
):
    patents_with_embeddings = pl.scan_parquet(embeddings_path).with_row_index(
        "voyager_index"
    )
    raw_controls = pl.scan_parquet(controls_path)

    n_neighbours = (
        patents_with_embeddings.unique("patent_id")
        # NOTE: this is where the top 0.1% is defined
        .select(pl.len() / 1000)
        .collect()
        .item(0, 0)
    )

    print("neighbours: ", ceil(n_neighbours))

    embeddings = (
        patents_with_embeddings.select("embedding")
        .collect()
        .get_column("embedding")
        .to_numpy()
    )

    print("querying NNs")

    neighbours, _ = voyager_index.query(embeddings, ceil(n_neighbours))

    patents_with_neighbours = (
        patents_with_embeddings.select("patent_id")
        .with_columns(neighbours=neighbours)
        .explode(pl.col("neighbours"))
        .rename({"patent_id": "citing_patent_id", "neighbours": "voyager_index"})
    )

    controls = (
        raw_controls.join(
            patents_with_embeddings.select(["patent_id", "voyager_index"]),
            left_on="control_patent_id",
            right_on="patent_id",
        )
        .join(patents_with_neighbours, on=["citing_patent_id", "voyager_index"])
        .select(["citing_patent_id", "cited_patent_id", "control_patent_id"])
        .unique()
    )

    print("sinking data")

    controls.sink_parquet(save_path)


if __name__ == "__main__":
    if Path("data", "interim", "index.voy").exists():
        print("index exists")
    else:
        print("creating index")
        create_index()

    print("loading index")
    index = open_index()

    print("finding neighbours")
    match_controls(index)
