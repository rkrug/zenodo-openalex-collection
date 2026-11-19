# The finer intervals to recheck in this run: all of them (`every`), or, for a rolling
# recheck (`per_run`), the next `per_run` after the last one checked (`last`, kept with
# the data), in chronological order, starting again at the beginning after the end.
recheck_select <- function(fine, per_run = NULL, last = NULL) {
  if (is.null(per_run) || per_run >= nrow(fine)) return(fine)
  pos <- match(last %||% NA_character_, fine$bucket)
  if (is.na(pos)) pos <- 0
  idx <- (pos + seq_len(per_run) - 1) %% nrow(fine) + 1
  fine[idx, , drop = FALSE]
}
