# Is the full recheck (config `recheck: every`) due? Due when it never ran for this entry,
# or when `recheck$every` (week, month, quarter or year) has passed since the last one,
# whose date is kept with the data in `file`. Rolling rechecks (`per_run`) run every time.
recheck_due <- function(cfg, file, today = Sys.Date()) {
  if (is.null(cfg$recheck)) return(FALSE)
  if (!is.null(cfg$recheck$per_run)) return(TRUE)
  if (!file.exists(file)) return(TRUE)
  last <- as.Date(jsonlite::read_json(file)$date)
  step <- c(week = "week", month = "month", quarter = "3 months", year = "year")[[cfg$recheck$every]]
  today >= seq(last, by = step, length.out = 2)[2]
}
