from pathlib import Path
import shutil
import gzip

import polars as pl

from lse_diss.data.bulk_data import download_file

download_file(
    "https://github.com/OSMNames/OSMNames/releases/download/v2.0.4/planet-latest_geonames.tsv.gz",
    Path("data", "misc", "OSMNames"),
)


def extract_names(
    path=Path("data", "misc", "OSMNames", "planet-latest_geonames.tsv.gz"),
):
    with gzip.open(path, "rb") as f_in:
        with open(path.with_suffix(""), "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)

    path.unlink()

    save_path = path.with_suffix("").with_suffix(".parquet")
    pl.scan_csv(
        path.with_suffix(""), separator="\t", infer_schema_length=None
    ).sink_parquet(save_path)
    save_path.unlink()


extract_names()
