import shutil
from pathlib import Path

import httpx
import polars as pl
from tqdm import tqdm


def download_file(url):
    path = Path("data", "external", "bulk_downloads")
    path.mkdir(parents=True, exist_ok=True)

    file_name = url.split("/")[-1]
    file_path = path / file_name

    with open(file_path, "wb") as f:
        with httpx.stream("GET", url) as r:
            r.raise_for_status()
            size = int(r.headers.get("content-length", 0))
            with tqdm(total=size, unit="iB", unit_scale=True) as pbar:
                for data in r.iter_bytes():
                    pbar.update(len(data))
                    f.write(data)

    shutil.unpack_archive(file_path, path)
    file_path.unlink()


def convert_files():
    tsv_path = Path("data", "external", "bulk_downloads")
    parquet_path = Path("data", "raw", "bulk_downloads")
    parquet_path.mkdir(parents=True, exist_ok=True)

    for file_path in tsv_path.iterdir():
        if file_path.is_file():
            save_path = parquet_path / file_path.with_suffix(".parquet").name
            pl.scan_csv(
                file_path, separator="\t", infer_schema_length=None
            ).sink_parquet(save_path)


if __name__ == "__main__":
    urls = pl.read_json(Path("references", "bulk_urls.json")).to_dict()

    # Extract URLs from the polars Series and download each file
    for name, url_series in urls.items():
        url = url_series[0]  # Extract the URL string from the Series
        print(f"Downloading {name}...")
        download_file(url)
        print(f"Downloaded and extracted {name}")

    # Conversion to parquet
    convert_files()
