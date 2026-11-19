# Counts the records of each interval (config `interval`: month, quarter, year or all) of
# the config's range on Zenodo (1 request per interval) and compares them with the cached
# interval folders. Returns the intervals whose counts differ (0 rows when nothing
# changed). Only an addition and a removal with the same number of versions in the same
# interval go unnoticed.
#
# Recheck (config `recheck: {every, interval}`): when due, Zenodo and the cached data are
# counted in the finer `recheck$interval` instead (cached data grouped by `created`, no
# extra requests); every changed fine interval marks the storage interval containing it.
# The date is stored in output/<name>/zenodo_recheck.json (saved with the data only when
# the run succeeds, so a failed recheck is repeated on the next run).
#
# Full re-download (env ZOC_FULL = "true", manual runs): all intervals are returned.
#
# Cached folders of other intervals (changed `interval`, `from` or `to`) are returned
# with new = 0, so the download removes them.
check_zenodo <- function(cfg, dir) {
  interval <- zenodo_interval(cfg)
  recheck_file <- file.path(dirname(dir), "zenodo_recheck.json")
  full <- identical(tolower(Sys.getenv("ZOC_FULL")), "true")
  recheck <- !full && recheck_due(cfg, recheck_file)
  na_null <- \(x) if (is.na(x)) NULL else x
  count <- \(b) vapply(seq_len(nrow(b)), \(i) {
    zenodo_count(cfg, zenodo_query(na_null(b$from[i]), na_null(b$to[i])))
  }, 1)

  b <- zenodo_buckets(cfg)
  old <- zenodo_bucket_counts(dir)
  b$old <- unname(old[b$bucket])
  b$old[is.na(b$old)] <- 0
  if (recheck) {
    fine <- zenodo_buckets(utils::modifyList(cfg, list(interval = cfg$recheck$interval)))
    fine$new <- count(fine)
    created <- zenodo_id_table(dir, "created")$created
    cached <- table(zenodo_bucket_label(created, cfg$recheck$interval))
    fine$old <- as.vector(cached[fine$bucket])
    fine$old[is.na(fine$old)] <- 0
    start <- zenodo_bucket_start(fine$bucket)
    start[is.na(start)] <- substr(cfg$from %||% "2013-01-01", 1, 10)
    fine$storage <- zenodo_bucket_label(start, interval)
    b$new <- vapply(b$bucket, \(x) sum(fine$new[fine$storage == x]), 1)
    hit <- unique(fine$storage[fine$new != fine$old])
  } else {
    b$new <- count(b)
    hit <- character()
  }
  gone <- setdiff(names(old), b$bucket)
  if (length(gone)) {
    b <- rbind(b, data.frame(bucket = gone, from = NA, to = NA, old = unname(old[gone]), new = 0))
  }
  sel <- b$new != b$old | b$bucket %in% hit | (full & (b$new > 0 | b$old > 0))
  changed <- b[sel, c("bucket", "from", "to", "old", "new")]
  rownames(changed) <- NULL
  mode <- if (full) "full re-download" else if (recheck) {
    sprintf("recheck by %s", cfg$recheck$interval)
  } else interval
  message(sprintf("%s: %d intervals checked (%s), %d records on Zenodo, %d to download%s",
                  cfg$zenodo_community, nrow(b) - length(gone), mode, sum(b$new), nrow(changed),
                  if (nrow(changed)) paste0(": ", toString(sprintf("%s (%d -> %d)",
                    changed$bucket, changed$old, changed$new))) else ""))
  if (recheck) {
    dir.create(dirname(recheck_file), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(list(date = as.character(Sys.Date()), interval = cfg$recheck$interval),
                         recheck_file, auto_unbox = TRUE, pretty = TRUE)
  }
  changed
}
