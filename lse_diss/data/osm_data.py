from pathlib import Path

import polars as pl

from lse_diss.data.bulk_data import download_file


def extract_names(
    path=Path("data", "misc", "OSMNames", "planet-latest_geonames.tsv"),
):
    save_path = path.with_suffix("").with_suffix(".parquet")

    pl.scan_csv(
        path.with_suffix(""), separator="\t", infer_schema_length=None
    ).sink_parquet(save_path)

    save_path.unlink()


if __name__ == "__main__":
    download_file(
        "https://github.com/OSMNames/OSMNames/releases/download/v2.0.4/planet-latest_geonames.tsv.gz",
        Path("data", "misc", "OSMNames"),
    )

    extract_names()
