# Interval sizes for the check and the download (config field `interval`).
zenodo_intervals <- c("month", "quarter", "year", "all")

# The entry's interval; missing or ~ = year.
zenodo_interval <- function(cfg) cfg$interval %||% "year"
