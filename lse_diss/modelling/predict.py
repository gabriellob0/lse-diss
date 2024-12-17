import polars as pl
from sentence_transformers import SentenceTransformer, util
from itertools import combinations
from tqdm import tqdm

# Read the CSV file
df = pl.read_csv("data/interim/patents_test.csv")

# Initialize the model
model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

# Get abstracts list
abstracts = df['patent_abstract'].to_list()
patent_ids = df['patent_id'].to_list()

print("Computing embeddings...")
# Compute embeddings for all abstracts at once (more efficient)
embeddings = model.encode(abstracts, convert_to_tensor=True)

# Create all possible pairs of indices
pairs = list(combinations(range(len(abstracts)), 2))
total_comparisons = len(pairs)

print(f"Computing {total_comparisons} comparisons...")
# Calculate similarities for all pairs
similarities = []
for i, j in tqdm(pairs, total=total_comparisons):
    similarity = util.pytorch_cos_sim(embeddings[i], embeddings[j]).item()
    similarities.append({
        'patent_id_1': patent_ids[i],
        'patent_id_2': patent_ids[j],
        'similarity': similarity
    })

# Convert results to polars DataFrame
results = pl.DataFrame(similarities)

# Sort by similarity in descending order
results = results.sort('similarity', descending=True)

print("\nTop 10 most similar patent pairs:")
print(results.head(10))