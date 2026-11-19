# Counts the records of each month of the config's range on Zenodo (1 request per month)
# and compares them with the cached month folders. Returns the months whose counts differ
# (0 rows when nothing changed). Catches additions and removals in each month; only an
# addition and a removal with the same number of versions in the same month go unnoticed.
check_zenodo <- function(cfg, dir) {
  b <- zenodo_months(cfg)
  na_null <- \(x) if (is.na(x)) NULL else x
  b$new <- vapply(seq_len(nrow(b)), \(i) {
    zenodo_count(cfg, zenodo_query(na_null(b$from[i]), na_null(b$to[i])))
  }, 1)
  old <- zenodo_month_counts(dir)
  b$old <- unname(old[b$month])
  b$old[is.na(b$old)] <- 0
  # cached months outside the range (e.g. after changing from/to): to be removed
  gone <- setdiff(names(old), b$month)
  if (length(gone)) {
    b <- rbind(b, data.frame(month = gone, from = NA, to = NA, new = 0, old = unname(old[gone])))
  }
  changed <- b[b$new != b$old, c("month", "from", "to", "old", "new")]
  rownames(changed) <- NULL
  message(sprintf("%s: %d months checked, %d records on Zenodo, %d changed months%s",
                  cfg$zenodo_community, nrow(b), sum(b$new), nrow(changed),
                  if (nrow(changed)) paste0(": ", toString(sprintf("%s (%d -> %d)",
                    changed$month, changed$old, changed$new))) else ""))
  changed
}
