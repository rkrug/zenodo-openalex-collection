# Monday of ISO week `week` of ISO year `year` (Dates).
zenodo_iso_week_monday <- function(year, week) {
  jan4 <- as.Date(sprintf("%d-01-04", as.integer(year)))
  jan4 - (as.integer(format(jan4, "%u")) - 1) + 7 * (as.integer(week) - 1)
}
