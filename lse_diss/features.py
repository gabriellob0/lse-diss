import polars as pl

originating_query = (
    pl.scan_parquet("data/raw/patents")
    .with_columns(pl.col("patent_date").str.to_date())
    .filter(pl.col("patent_date").is_between(pl.date(2001, 1, 1), pl.date(2001, 12, 12)))
)

originating_2000 = originating_query.collect()

originating_2000.collect_schema
originating_2000.tail
