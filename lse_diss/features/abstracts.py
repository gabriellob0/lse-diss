from pathlib import Path

import polars as pl


def filter_abstracts(
    patents_path=Path("data", "interim", "patents"),
    controls_path=Path("data", "interim", "controls"),
    save_path=Path("data", "interim", "abstracts.parquet"),
):
    patents = (
        pl.scan_parquet(patents_path).select("patent_id", "patent_abstract").unique()
    )

    controls = (
        pl.scan_parquet(controls_path)
        .select("citing_patent_id", "control_patent_id")
        .unpivot()
        .select("value")
        .unique()
    )

    abstracts = patents.join(
        controls, left_on="patent_id", right_on="value", how="inner"
    )

    abstracts.sink_parquet(save_path)


def filter_embeddings(
    embeddings_path=Path("data", "misc", "embeddings"),
    controls_path=Path("data", "interim", "controls_alt"),
    save_path=Path("data", "processed", "embeddings_alt"),
):
    save_path.mkdir(parents=True, exist_ok=True)

    embeddings = pl.scan_parquet(embeddings_path)

    controls = (
        pl.scan_parquet(controls_path)
        .select("citing_patent_id", "control_patent_id")
        .unpivot()
        .select("value")
        .unique()
    )

    abstracts = embeddings.join(
        controls, left_on="patent_id", right_on="value", how="inner"
    )

    abstracts.sink_parquet(
        pl.PartitionMaxSize(
            save_path / "embedded_abstracts_{part}.parquet", max_size=512_000
        )
    )


if __name__ == "__main__":
    filter_abstracts()
