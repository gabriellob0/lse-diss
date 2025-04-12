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
    controls_path=Path("data", "interim", "controls"),
    embeddings_path=Path("data", "processed", "embeddings"),
    save_path=Path("data", "processed", "controls.parquet"),
):
    potential_controls = pl.scan_parquet(controls_path)
    indexed_embeddings = pl.scan_parquet(embeddings_path)

    citing_ids = potential_controls.select("citing_patent_id").unique()

    n_citing = indexed_embeddings.select(pl.len()).collect().item(0, 0)
    n_neighbours = ceil(n_citing / 100)
    print(n_neighbours)

    citing_embeddings = citing_ids.join(
        indexed_embeddings.select(["patent_id", "embedding"]),
        left_on="citing_patent_id",
        right_on="patent_id",
        how="left",
        validate="1:1",
    )

    embeddings = citing_embeddings.collect().get_column("embedding").to_numpy()

    neighbours, _ = voyager_index.query(embeddings, n_neighbours)

    citing_neighbours = (
        citing_ids.with_columns(neighbour=neighbours)
        .explode(pl.col("neighbour"))
        .join(
            indexed_embeddings.select(["index", "patent_id"]),
            left_on="neighbour",
            right_on="index",
        )
        .select(
            pl.col("citing_patent_id"), pl.col("patent_id").alias("control_patent_id")
        )
    )

    controls = potential_controls.join(
        citing_neighbours, on=["citing_patent_id", "control_patent_id"]
    )

    controls.sink_parquet(save_path)
