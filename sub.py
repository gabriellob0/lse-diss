import lse_diss.features as ft

ft.make_locations()

raw_patents = ft.load_patents()
trimmed_patents = ft.trim_abstracts(raw_patents)

ft.save_patents(trimmed_patents)

ft.filter_citations()

agg_patents = ft.make_originating()
treated_pairs = ft.make_treated(agg_patents)

potential_controls = ft.make_controls(agg_patents, treated_pairs)
test = ft.remove_cited(potential_controls)