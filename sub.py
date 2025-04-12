import lse_diss.features as ft
import lse_diss.modelling.ann as ann

import polars as pl

ft.make_locations()

raw_patents = ft.load_patents()
trimmed_patents = ft.trim_abstracts(raw_patents)

ft.save_patents(trimmed_patents)

ft.filter_citations()

program_duration=3

agg_patents = ft.make_originating()
treated_pairs = ft.make_treated(agg_patents, duration=program_duration)
treated_pairs.select(pl.len()).collect()

ft.save_controls(agg_patents, treated_pairs, duration=program_duration)

pl.scan_parquet("data/interim/controls").select(pl.len()).collect(engine="streaming")

ft.filter_abstracts()

#ann.create_index()
ann.match_controls(ann.open_index())