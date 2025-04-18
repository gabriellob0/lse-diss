from pathlib import Path

from lse_diss.features.controls import make_originating, make_treated, save_controls
from lse_diss.features.abstracts import filter_embeddings

BASE_YEAR = 5

originating = make_originating(base_year=BASE_YEAR, duration_months=0, duration_years=5)

treated = make_treated(originating, base_year=BASE_YEAR, duration=20)

save_controls(
    originating,
    treated,
    duration=20,
    search_range=180,
    path=Path("data", "interim", "controls_alt"),
)

filter_embeddings()
