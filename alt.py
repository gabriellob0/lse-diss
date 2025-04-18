from pathlib import Path

from lse_diss.features.controls import make_originating, make_treated, save_controls
from lse_diss.features.abstracts import filter_embeddings
from lse_diss.modelling.ann import create_index, open_index, match_controls

#BASE_YEAR = 2005

#originating = make_originating(base_year=BASE_YEAR, duration_months=0, duration_years=1)

#treated = make_treated(originating, base_year=BASE_YEAR, duration=5)

#save_controls(
#    originating,
#    treated,
#    duration=5,
#    search_range=180,
#    path=Path("data", "interim", "controls_alt"),
#    batch_size=1000
#)

#filter_embeddings()

#create_index(save_path=Path("data", "misc"))

index = open_index(Path("data", "misc", "index.voy"))

# 155 NNs
match_controls(
    index,
    embeddings_path=Path("data", "processed", "embeddings_alt"),
    controls_path=Path("data", "interim", "controls_alt"),
    save_path=Path("data", "processed", "controls_alt.parquet"),
    match_quality=1000
)