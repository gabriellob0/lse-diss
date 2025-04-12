from pathlib import Path

import polars as pl

from voyager import Index, Space

def create_index(embeddings_path=Path("data", "processed", "embeddings"), save_path=Path("data", "interim", "indexes")):
    save_path.mkdir(parents=True, exist_ok=True)
    file_path = str(save_path / "index.voy")

    df = pl.scan_parquet(embeddings_path).collect()
    embeddings = df.get_column("embedding").to_numpy()

    dimension = embeddings.shape[1]
    index = Index(Space.Cosine, num_dimensions=dimension)
    index.add_items(embeddings)

    index.save(str(file_path))

#create_index()

with open(str(Path("data", "interim", "indexes", "index.voy")), 'rb') as f:
    index = Index.load(f) 

index.num_elements

# plan:
# filter all citing patents
# for each citing patent get top 1% nearest neighbour
# construct dataset with these
# join on citing and control id from potential control

# after that:
# go back to features
# join all the locations
# calculate the distances (between citing and cited and control and cited)
# move to data analysis



#neighbors, distances = index.query(embeddings[5], k=3)

#abstracts[5]
#abstracts[17281]
#abstracts[75715]