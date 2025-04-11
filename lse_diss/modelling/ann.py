from voyager import Index, Space

dimension = embeddings.shape[1]
index = Index(Space.Cosine, num_dimensions=dimension)

index.add_items(embeddings)
#index.save("data/interim/index.voy")

neighbors, distances = index.query(embeddings[5], k=3)

abstracts[5]
abstracts[1821]
abstracts[177]