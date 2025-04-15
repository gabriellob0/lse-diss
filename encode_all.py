from pathlib import Path

import polars as pl

from lse_diss.modelling.embeddings import make_embeddings


def encode_all():
    patents_path = Path("data", "interim", "patents")
    abstracts_path = Path("data", "misc", "abstracts")
    embeddings_path = Path("data", "misc", "embeddings")

    patents = (
        pl.scan_parquet(patents_path).select(["patent_id", "patent_abstract"]).unique()
    )

    if embeddings_path.exists():
        print("rewriting abstracts")
        [file_path.unlink() for file_path in abstracts_path.glob("*")]

        embeddings = pl.scan_parquet(embeddings_path).select("patent_id")
        patents.join(embeddings, on="patent_id", how="anti").sink_parquet(
            pl.PartitionMaxSize(
                abstracts_path / "abstract_{part}.parquet", max_size=512_000
            )
        )
    else:
        print("filtering abstracts")
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

    make_embeddings(abstracts_path, embeddings_path)


if __name__ == "__main__":
    encode_all()
