from pathlib import Path

import polars as pl
from sentence_transformers import SentenceTransformer
from voyager import Index, Space

patents = (
    pl.scan_parquet(Path("data", "interim", "patents"))
    .slice(0, 10000)
    .select(["patent_id", "patent_abstract"])
    .unique()
    .collect()
)

abstracts = patents.get_column("patent_abstract").to_list()

model = SentenceTransformer("nomic-ai/nomic-embed-text-v2-moe", trust_remote_code=True, truncate_dim=256)
embeddings = model.encode(abstracts, prompt_name="passage", show_progress_bar=True)

dimension = embeddings.shape[1]
index = Index(Space.Cosine, num_dimensions=dimension)

index.add_items(embeddings)
index.save("data/interim/index.voy")

neighbors, distances = index.query(embeddings[5], k=3)

abstracts[5]
abstracts[1821]
abstracts[177]