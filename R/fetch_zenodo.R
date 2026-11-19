# Downloads the intervals the check found changed into `dir`/<interval>/.
# Consecutive changed intervals with fewer than 10,000 records together are downloaded in
# one query and split into their folders by `created`; the counts from the check are
# reused, so no extra count requests are needed. Everything is downloaded into a temporary
# folder first and replaces the old interval folders only when complete, so an interrupted
# download leaves the old data intact. Intervals now empty are removed.
fetch_zenodo <- function(cfg, changed, dir, limit = 10000) {
  interval <- zenodo_interval(cfg)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  before <- zenodo_id_table(dir)
  unlink(list.files(dir, "[.]parquet$", full.names = TRUE)) # old flat layout
  tmp_root <- paste0(dir, ".tmp")
  unlink(tmp_root, recursive = TRUE)
  na_null <- \(x) if (is.na(x)) NULL else x

  # runs of consecutive intervals to download together
  get <- changed[changed$new > 0, ]
  run <- integer(nrow(get))
  for (i in seq_len(nrow(get))) {
    joins <- i > 1 && identical(get$to[i - 1], get$from[i]) &&
      sum(get$new[run == run[i - 1]]) + get$new[i] < limit
    run[i] <- if (i == 1) 1L else if (joins) run[i - 1] else run[i - 1] + 1L
  }
  for (r in unique(run)) {
    g <- get[run == r, ]
    raw <- file.path(tmp_root, paste0(".run", r))
    dir.create(raw, recursive = TRUE)
    fetch_zenodo_range(cfg, raw, na_null(g$from[1]), na_null(g$to[nrow(g)]), n = sum(g$new))
    if (nrow(g) == 1) {
      file.rename(raw, file.path(tmp_root, g$bucket))
      next
    }
    # several intervals (< 10,000 records together): split by created
    d <- dplyr::collect(arrow::open_dataset(raw))
    lab <- zenodo_bucket_label(d$created, interval)
    clean <- \(x, open) if (is.na(x)) open else gsub("[^0-9A-Za-z-]", "", x)
    for (i in seq_len(nrow(g))) {
      b <- g$bucket[i]
      dir.create(file.path(tmp_root, b))
      stem <- paste(clean(g$from[i], "start"), clean(g$to[i], "now"), sep = "_")
      arrow::write_parquet(d[lab == b, ], file.path(tmp_root, b, paste0(stem, "_001.parquet")))
    }
    unlink(raw, recursive = TRUE)
  }
  for (b in changed$bucket) {
    unlink(file.path(dir, b), recursive = TRUE)
    if (dir.exists(file.path(tmp_root, b))) file.rename(file.path(tmp_root, b), file.path(dir, b))
  }
  unlink(tmp_root, recursive = TRUE)

  after <- zenodo_id_table(dir)
  stopifnot(!anyDuplicated(after$id))
  # Last change (kept until the next change): deposits = concept DOIs, records = versions
  if (nrow(changed)) {
    n <- \(a, b) length(setdiff(unique(a), unique(b)))
    jsonlite::write_json(
      list(
        date = format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"),
        added_deposits = n(after$conceptdoi, before$conceptdoi),
        removed_deposits = n(before$conceptdoi, after$conceptdoi),
        added_records = n(after$id, before$id),
        removed_records = n(before$id, after$id)
      ),
      file.path(dirname(dir), "zenodo_changes.json"),
      auto_unbox = TRUE, pretty = TRUE
    )
  }
  dir
}
