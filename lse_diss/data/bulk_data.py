import gzip
import shutil
from pathlib import Path

import httpx
import polars as pl
import yaml
from tqdm import tqdm


def download_file(url, path=Path("data", "misc", "bulk_downloads")):
    path.mkdir(parents=True, exist_ok=True)

    file_name = url.split("/")[-1]
    file_path = path / file_name

    with open(file_path, "wb") as f:
        with httpx.stream("GET", url, follow_redirects=True) as r:
            r.raise_for_status()
            size = int(r.headers.get("content-length", 0))
            with tqdm(total=size, unit="iB", unit_scale=True) as pbar:
                for data in r.iter_bytes():
                    pbar.update(len(data))
                    f.write(data)

        # Try to unpack with shutil.unpack_archive
    try:
        shutil.unpack_archive(file_path, path)
        file_path.unlink()
        return

    except Exception:
        # If that fails, check if it's a .gz file and try gzip unpacking
        if file_path.suffix == ".gz":
            try:
                with gzip.open(file_path, "rb") as f_in:
                    output_path = file_path.with_suffix("")
                    with open(output_path, "wb") as f_out:
                        shutil.copyfileobj(f_in, f_out)
                file_path.unlink()
                return
            except Exception as e:
                print(f"Failed to unpack gzipped file {file_name}: {e}")

    # If we reach here, both unpacking methods failed
    print(f"Keeping original file {file_name}")


def convert_files():
    tsv_path = Path("data", "misc", "bulk_downloads")
    parquet_path = Path("data", "raw", "bulk_downloads")
    parquet_path.mkdir(parents=True, exist_ok=True)

    for file_path in tsv_path.iterdir():
        if file_path.is_file():
            save_path = parquet_path / file_path.with_suffix(".parquet").name
            pl.scan_csv(
                file_path, separator="\t", infer_schema_length=None
            ).sink_parquet(save_path)


if __name__ == "__main__":
    with open(Path("lse_diss", "config.yaml")) as stream:
        try:
            config = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    urls = config["bulk_urls"]

    # Extract URLs from the polars Series and download each file
    for name, url in urls.items():
        print(f"Downloading {name}...")
        download_file(url)
        print(f"Downloaded and extracted {name}")

    # Conversion to parquet
    convert_files()
