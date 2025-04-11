from math import ceil
from pathlib import Path

import polars as pl
from sentence_transformers import SentenceTransformer

BATCH_SIZE = 25000
OUTPUT_DIR = Path("data", "processed", "embeddings")
OUTPUT_DIR.mkdir(exist_ok=True, parents=True)

model = SentenceTransformer(
    "nomic-ai/nomic-embed-text-v2-moe", trust_remote_code=True, truncate_dim=256
)

patents = pl.scan_parquet(Path("data", "interim", "abstracts.parquet"))

total_rows = patents.select(pl.len()).collect().item(0, 0)
total_batches = ceil(total_rows / BATCH_SIZE)

for i in range(total_batches):
    start = i * BATCH_SIZE
    end = min((i + 1) * BATCH_SIZE, total_rows)

    file_path = OUTPUT_DIR / f"embedded_abstracts_{i}.parquet"

    sliced_patents = patents.slice(start, end).collect()
    abstracts = sliced_patents.get_column("patent_abstract").to_list()

    embeddings = model.encode(abstracts, prompt_name="passage", batch_size=64, show_progress_bar=True)

    sliced_patents.select(["index", "patent_id"]).with_columns(
        embedding=embeddings
    ).write_parquet(file_path)
