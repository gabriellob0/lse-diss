from lse_diss.features import clean_patents, trim_abstracts, clean_citations, make_treated

clean_patents()
trim_abstracts()

# I need to be very carefull about these two functions, they have not been fully tested
clean_citations()
df = make_treated()