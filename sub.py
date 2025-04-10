from lse_diss.features import make_locations, load_patents, trim_abstracts, save_patents

make_locations()

raw_patents = load_patents()
trimmed_patents = trim_abstracts(raw_patents)

save_patents(trimmed_patents)