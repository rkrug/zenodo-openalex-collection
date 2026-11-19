# Cached records per month: rows in each month folder of `dir`, named by month.
zenodo_month_counts <- function(dir) {
  months <- list.dirs(dir, recursive = FALSE, full.names = FALSE)
  months <- grep("^[0-9]{4}-[0-9]{2}$", months, value = TRUE)
  vapply(stats::setNames(months, months), \(m) nrow(arrow::open_dataset(file.path(dir, m))), 1)
}
