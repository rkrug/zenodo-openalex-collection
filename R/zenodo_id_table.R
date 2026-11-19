# Record IDs and concept DOIs of all parquet files below `dir` (empty table if none).
zenodo_id_table <- function(dir) {
  if (!length(list.files(dir, "[.]parquet$", recursive = TRUE))) {
    return(data.frame(id = character(), conceptdoi = character()))
  }
  arrow::open_dataset(dir) |>
    dplyr::select(id, conceptdoi) |>
    dplyr::collect()
}
