from pathlib import Path

import polars as pl

from lse_diss.modelling.embeddings import make_embeddings


def encode_all():
    abstracts_path = Path("data", "misc", "abstracts")
    abstracts_path.mkdir(parents=True, exist_ok=True)

    (
        pl.scan_parquet(Path("data", "interim", "patents"))
        .select("patent_id", "patent_abstract")
        .unique()
        .sink_parquet(
            pl.PartitionMaxSize(
                abstracts_path / "abstract_{part}.parquet", max_size=512_000
            )
        )
    )

    make_embeddings(abstracts_path, Path("data", "misc", "embeddings"))


if __name__ == "__main__":
    encode_all()
