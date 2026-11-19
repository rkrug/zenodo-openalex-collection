# Downloads the months the check found changed into `dir`/<YYYY-MM>/. Each month is
# downloaded into a temporary folder that replaces the old month folder only when complete,
# so an interrupted download leaves the old data intact. Months now empty are removed.
fetch_zenodo <- function(cfg, changed, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  before <- zenodo_id_table(dir)
  unlink(list.files(dir, "[.]parquet$", full.names = TRUE)) # old flat layout
  tmp_root <- paste0(dir, ".tmp")
  na_null <- \(x) if (is.na(x)) NULL else x
  for (i in seq_len(nrow(changed))) {
    final <- file.path(dir, changed$month[i])
    tmp <- file.path(tmp_root, changed$month[i])
    unlink(tmp, recursive = TRUE)
    if (changed$new[i] > 0) {
      dir.create(tmp, recursive = TRUE)
      fetch_zenodo_range(cfg, tmp, na_null(changed$from[i]), na_null(changed$to[i]))
    }
    unlink(final, recursive = TRUE)
    if (dir.exists(tmp)) file.rename(tmp, final)
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
