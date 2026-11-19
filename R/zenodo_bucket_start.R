# First day of an interval label ("2024-03", "2024-Q2", "2024"); NA for "all".
zenodo_bucket_start <- function(label) {
  out <- rep(NA_character_, length(label))
  m <- grepl("^[0-9]{4}-[0-9]{2}$", label)
  q <- grepl("^[0-9]{4}-Q[1-4]$", label)
  y <- grepl("^[0-9]{4}$", label)
  out[m] <- paste0(label[m], "-01")
  out[q] <- sprintf("%s-%02d-01", substr(label[q], 1, 4), (as.integer(substr(label[q], 7, 7)) - 1) * 3 + 1)
  out[y] <- paste0(label[y], "-01-01")
  out
}
