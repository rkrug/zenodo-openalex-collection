# Cached records per interval: rows in each interval folder of `dir`, named by interval.
zenodo_bucket_counts <- function(dir) {
  b <- list.dirs(dir, recursive = FALSE, full.names = FALSE)
  b <- grep("^([0-9]{4}(-[0-9]{2}|-Q[1-4])?|all)$", b, value = TRUE)
  vapply(stats::setNames(b, b), \(x) nrow(arrow::open_dataset(file.path(dir, x))), 1)
}
