# Columns `cols` of all parquet files below `dir` (empty table if none).
zenodo_id_table <- function(dir, cols = c("id", "conceptdoi")) {
  if (!length(list.files(dir, "[.]parquet$", recursive = TRUE))) {
    return(as.data.frame(stats::setNames(rep(list(character()), length(cols)), cols)))
  }
  arrow::open_dataset(dir) |>
    dplyr::select(dplyr::all_of(cols)) |>
    dplyr::collect()
}
