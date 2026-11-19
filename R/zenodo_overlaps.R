# Labels of the intervals in `storage` (data frame with bucket, from, to; NA = open end)
# that overlap any of the intervals in `fine`. A fine interval that spans two storage
# intervals (e.g. a week across a month end) marks both.
zenodo_overlaps <- function(fine, storage) {
  lo <- \(x) ifelse(is.na(x), "0000-01-01", substr(x, 1, 10))
  hi <- \(x) ifelse(is.na(x), "9999-12-31", substr(x, 1, 10))
  hit <- vapply(seq_len(nrow(storage)), \(i) {
    any(lo(fine$from) < hi(storage$to[i]) & hi(fine$to) > lo(storage$from[i]))
  }, NA)
  storage$bucket[hit]
}
