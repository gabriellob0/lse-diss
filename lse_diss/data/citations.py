import polars as pl

schema = {
    'patent_id': pl.Utf8,
    'citation_sequence': pl.Int64,
    'citation_patent_id': pl.Utf8,
    'citation_date': pl.Date,
    'citation_name': pl.Utf8,
    'citation_kind': pl.Utf8,
    'citation_category': pl.Utf8
}

# pl.scan_csv("data/raw/g_us_patent_citation.tsv", separator = "\t", rechunk = True, schema=schema).sink_parquet("data/raw/g_us_patent_citation.parquet")