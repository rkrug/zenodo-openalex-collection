# Is the thorough check (config `recheck`) due? Due when it never ran for this entry, or
# when `recheck$every` (month, quarter or year) has passed since the last one, whose date
# is kept with the data in `file`.
recheck_due <- function(cfg, file, today = Sys.Date()) {
  if (is.null(cfg$recheck)) return(FALSE)
  if (!file.exists(file)) return(TRUE)
  last <- as.Date(jsonlite::read_json(file)$date)
  step <- c(month = "month", quarter = "3 months", year = "year")[[cfg$recheck$every]]
  today >= seq(last, by = step, length.out = 2)[2]
}
