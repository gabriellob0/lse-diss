import os
import time
from pathlib import Path

import polars as pl
import psutil
from sentence_transformers import SentenceTransformer


def print_memory_usage():
    process = psutil.Process(os.getpid())
    mem_info = process.memory_info()
    print(f"Memory usage: {mem_info.rss / (1024 * 1024):.2f} MB")


print("cpu count", psutil.cpu_count())

print_memory_usage()

size = 5000

model = SentenceTransformer(
    "nomic-ai/nomic-embed-text-v2-moe", trust_remote_code=True, truncate_dim=256
)

start_time = time.time()

patents = (
    pl.scan_parquet(Path("data", "interim", "abstracts.parquet"))
    .slice(0, size)
    .collect()
)

abstracts = patents.get_column("patent_abstract").to_list()

embeddings = model.encode(abstracts, prompt_name="passage", show_progress_bar=True)

finish_time = time.time()

print_memory_usage()

print("total time: ", finish_time - start_time)
