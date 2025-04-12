from math import ceil
from pathlib import Path

import polars as pl
from voyager import Index, Space


def create_index(
    embeddings_path=Path("data", "processed", "embeddings"),
    save_path=Path("data", "interim", "indexes"),
):
    save_path.mkdir(parents=True, exist_ok=True)
    file_path = str(save_path / "index.voy")

    df = pl.scan_parquet(embeddings_path).collect()
    embeddings = df.get_column("embedding").to_numpy()

    dimension = embeddings.shape[1]
    index = Index(Space.Cosine, num_dimensions=dimension)
    index.add_items(embeddings)

    index.save(str(file_path))


def open_index(path=Path("data", "interim", "indexes", "index.voy")):
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
        # NOTE: this is where the top 1% is defined
        .select(pl.len() / 10000)
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
        .rename({"neighbours": "neighbour"})
    )

    controls = (
        raw_controls.join(
            patents_with_neighbours, left_on="citing_patent_id", right_on="patent_id"
        )
        .join(
            patents_with_embeddings.select(["patent_id", "voyager_index"]),
            left_on="control_patent_id",
            right_on="patent_id",
        )
        .filter(pl.col("voyager_index") == pl.col("neighbour"))
        .select(["citing_patent_id", "cited_patent_id", "control_patent_id"])
    )

    print("sinking data")

    controls.sink_parquet(save_path)


def match_controls2(
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
        # NOTE: this is where the top 1% is defined
        .select(pl.len() / 10000)
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
        raw_controls
        .join(
            patents_with_embeddings.select(["patent_id", "voyager_index"]),
            left_on="control_patent_id",
            right_on="patent_id",
        )
        .join(
            patents_with_neighbours,
            on=["citing_patent_id", "voyager_index"]
        )
    )

    print("sinking data")

    controls.sink_parquet(save_path)



#create_index()
match_controls2(open_index())
