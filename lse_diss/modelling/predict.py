import polars as pl
from sentence_transformers import SentenceTransformer
from annoy import AnnoyIndex

patents = pl.read_csv("data/interim/patents_test.csv")
abstracts = patents['patent_abstract'].to_list()

model = SentenceTransformer("all-MiniLM-L6-v2")
embeddings = model.encode(abstracts, show_progress_bar=True)

dimension = embeddings.shape[1]
annoy_index = AnnoyIndex(dimension, 'angular')

for i, v in enumerate(embeddings):
    annoy_index.add_item(i, v)

annoy_index.build(256)

annoy_index.get_n_items()
annoy_index.get_n_trees()
annoy_index.get_distance(0, 2)
len(annoy_index.get_item_vector(1))

nearest_neighbours = annoy_index.get_nns_by_item(0, 3)

result = (
    patents
    .with_row_index()
    .filter(pl.col("index").is_in(nearest_neighbours))
)

result[0, 2]
result[1, 2]