from math import ceil
from pathlib import Path
import re

import polars as pl
from sentence_transformers import SentenceTransformer


def make_embeddings(
    abstracts_path=Path("data", "interim", "abstracts.parquet"),
    save_path=Path("data", "processed", "embeddings"),
    batch_size=40000,
):
    save_path.mkdir(exist_ok=True, parents=True)

    j = -1
    file_pattern = re.compile(r"embedded_abstracts_(\d+)\.parquet")
    for file_path in save_path.glob("embedded_abstracts_*.parquet"):
        match = file_pattern.match(file_path.name)
        if match:
            j = max(j, int(match.group(1)))

    j = j + 1

    model = SentenceTransformer(
        "nomic-ai/nomic-embed-text-v2-moe", trust_remote_code=True, truncate_dim=256
    )

    patents = pl.scan_parquet(abstracts_path)

    total_rows = patents.select(pl.len()).collect().item(0, 0)
    total_batches = ceil(total_rows / batch_size)

    for i in range(total_batches):
        start = i * batch_size
        length = min(batch_size, total_rows - start)

        file_path = save_path / f"embedded_abstracts_{i + j}.parquet"

        sliced_patents = patents.slice(start, length).collect()
        abstracts = sliced_patents.get_column("patent_abstract").to_list()

        embeddings = model.encode(
            abstracts, prompt_name="passage", batch_size=64, show_progress_bar=True
        )

        # NOTE: I spot checked and the order is being preserved
        sliced_patents.select("patent_id").with_columns(
            embedding=embeddings
        ).write_parquet(file_path)


if __name__ == "__main__":
    make_embeddings()
