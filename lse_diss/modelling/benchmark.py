import time
from pathlib import Path

import polars as pl
from sentence_transformers import SentenceTransformer

start_time = time.time()

size = 20000

model = SentenceTransformer(
    "nomic-ai/nomic-embed-text-v2-moe", trust_remote_code=True, truncate_dim=256
)

patents = pl.scan_parquet(Path("data", "interim", "abstracts.parquet")).slice(0, size)

abstracts = patents.get_column("patent_abstract").to_list()

embeddings = model.encode(abstracts, prompt_name="passage", show_progress_bar=True)

finish_time = time.time()

print(finish_time - start_time)
