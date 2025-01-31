import pathlib
import shutil

import httpx
import polars as pl
from tqdm import tqdm


def download_file(url):
    path = pathlib.Path("data/raw")
    path.mkdir(parents=True, exist_ok=True)
    
    file_name = url.split("/")[-1]
    file_path = path / file_name 
    
    with open(file_path, "wb") as f:
        with httpx.stream("GET", url) as r:
            r.raise_for_status()
            size = int(r.headers.get('content-length', 0))
            with tqdm(total=size, unit='iB', unit_scale=True) as pbar:
                for data in r.iter_bytes():
                    pbar.update(len(data))
                    f.write(data)
    
    shutil.unpack_archive(file_path, path)
    file_path.unlink()

download_file("https://s3.amazonaws.com/data.patentsview.org/download/g_cpc_title.tsv.zip")

urls = pl.read_json("references/urls.json").to_dict()

schema = {
    'patent_id': pl.Utf8,
    'citation_sequence': pl.Int64,
    'citation_patent_id': pl.Utf8,
    'citation_date': pl.Date,
    'citation_name': pl.Utf8,
    'citation_kind': pl.Utf8,
    'citation_category': pl.Utf8
}

# pl.scan_csv("data/raw/g_us_patent_citation.tsv", separator = "\t", rechunk = True, schema=schema).sink_parquet("data/raw/g_us_patent_citation.parquet")