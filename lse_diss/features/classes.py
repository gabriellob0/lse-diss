from pathlib import Path

import polars as pl


def filter_classes(
    classes_path=Path("data", "raw", "bulk_downloads", "g_cpc_current.parquet"),
    patents_path=Path("data", "processed", "controls.parquet"),
    save_path=Path("data", "processed", "classes.parquet"),
):
    classes = (
        pl.scan_parquet(classes_path)
        .select(pl.col("patent_id").cast(pl.Utf8), pl.col("cpc_section"))
        .unique()
    )

    patents = (
        pl.scan_parquet(patents_path)
        .unpivot()
        .unique()
        .join(classes, left_on="value", right_on="patent_id", how="left")
        .with_columns(
            pl.when(pl.col("variable") == "cited_patent_id")
            .then(1)
            .otherwise(0)
            .alias("cited_dummy")
        )
        .select(
            pl.col("cpc_section"),
            pl.col("value").alias("patent_id"),
            pl.col("cited_dummy"),
        )
        .unique()
    )

    patents.sink_parquet(save_path)


if __name__ == "__main__":
    filter_classes()
