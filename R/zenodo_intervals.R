# Interval sizes for the check and the download (config field `interval`), finest first.
zenodo_intervals <- c("week", "month", "quarter", "year", "all")

# The entry's interval; missing or ~ = year.
zenodo_interval <- function(cfg) cfg$interval %||% "year"
