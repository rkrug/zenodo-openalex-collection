# Counts the records of each interval (month, quarter, year or all; config `interval`) of
# the config's range on Zenodo (1 request per interval) and compares them with the cached
# interval folders. Returns the intervals whose counts differ (0 rows when nothing
# changed). Catches additions and removals in each interval; only an addition and a
# removal with the same number of versions in the same interval go unnoticed.
# Cached folders of other intervals (changed `interval`, `from` or `to`) are returned
# with new = 0, so the download removes them.
check_zenodo <- function(cfg, dir) {
  b <- zenodo_buckets(cfg)
  na_null <- \(x) if (is.na(x)) NULL else x
  b$new <- vapply(seq_len(nrow(b)), \(i) {
    zenodo_count(cfg, zenodo_query(na_null(b$from[i]), na_null(b$to[i])))
  }, 1)
  old <- zenodo_bucket_counts(dir)
  b$old <- unname(old[b$bucket])
  b$old[is.na(b$old)] <- 0
  gone <- setdiff(names(old), b$bucket)
  if (length(gone)) {
    b <- rbind(b, data.frame(bucket = gone, from = NA, to = NA, new = 0, old = unname(old[gone])))
  }
  changed <- b[b$new != b$old, c("bucket", "from", "to", "old", "new")]
  rownames(changed) <- NULL
  message(sprintf("%s: %d intervals (%s) checked, %d records on Zenodo, %d changed%s",
                  cfg$zenodo_community, nrow(b) - length(gone), cfg$interval %||% "month",
                  sum(b$new), nrow(changed),
                  if (nrow(changed)) paste0(": ", toString(sprintf("%s (%d -> %d)",
                    changed$bucket, changed$old, changed$new))) else ""))
  changed
}
