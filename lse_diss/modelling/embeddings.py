import polars as pl
from sentence_transformers import SentenceTransformer
from voyager import Index, Space

patents = pl.read_csv("data/interim/patents_test.csv")
#patents = pl.read_parquet("data/raw/g_patent_abstract.parquet")
abstracts = patents['patent_abstract'].to_list()

model = SentenceTransformer("all-MiniLM-L6-v2")
embeddings = model.encode(abstracts, show_progress_bar=True)

dimension = embeddings.shape[1]
index = Index(Space.Cosine, num_dimensions=dimension)

index.add_items(embeddings)

neighbors, distances = index.query(embeddings[5], k=3)

abstracts[5]
abstracts[6510]
abstracts[13582]