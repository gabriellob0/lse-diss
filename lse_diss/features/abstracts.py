from pathlib import Path

import polars as pl


def filter_abstracts(
    patents_path=Path("data", "interim", "patents"),
    controls_path=Path("data", "interim", "controls"),
    save_path=Path("data", "interim", "abstracts.parquet"),
):
    patents = (
        pl.scan_parquet(patents_path).select("patent_id", "patent_abstract").unique()
    )

    controls = (
        pl.scan_parquet(controls_path)
        .select("citing_patent_id", "control_patent_id")
        .unpivot()
        .select("value")
        .unique()
    )

    abstracts = patents.join(
        controls, left_on="patent_id", right_on="value", how="inner"
    )

    abstracts.sink_parquet(save_path)
