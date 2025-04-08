from pathlib import Path

import polars as pl
from sentence_transformers import SentenceTransformer
from voyager import Index, Space

patents = (
    pl.scan_parquet(Path("data", "processed", "patents"))
    .slice(0, 100000)
    .select(["patent_id", "patent_abstract"])
    .unique()
    .collect()
)

abstracts = patents.get_column("patent_abstract").to_list()

model = SentenceTransformer("all-MiniLM-L6-v2")
embeddings = model.encode(abstracts, show_progress_bar=True)

dimension = embeddings.shape[1]
index = Index(Space.Cosine, num_dimensions=dimension)

index.add_items(embeddings)

neighbors, distances = index.query(embeddings[5], k=3)

abstracts[5]
abstracts[3]
abstracts[38]