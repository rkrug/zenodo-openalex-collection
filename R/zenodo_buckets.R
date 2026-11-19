# Intervals [from, to) covering the config's range, in the size given by `interval`
# (default month). NA = open end (from: before Zenodo's launch in 2013, to: until now).
zenodo_buckets <- function(cfg) {
  interval <- zenodo_interval(cfg)
  if (interval == "all") {
    return(data.frame(bucket = "all", from = cfg$from %||% NA_character_,
                      to = cfg$to %||% NA_character_))
  }
  day <- \(x) as.Date(substr(x, 1, 10))
  start <- day(cfg$from %||% "2013-01-01")
  end <- day(cfg$to %||% as.character(Sys.Date() + 1))
  first <- switch(interval,
    month = format(start, "%Y-%m-01"),
    quarter = sprintf("%s-%02d-01", format(start, "%Y"),
                      (as.integer(format(start, "%m")) - 1) %/% 3 * 3 + 1),
    year = format(start, "%Y-01-01")
  )
  b <- seq(as.Date(first), end, by = c(month = "month", quarter = "3 months", year = "year")[[interval]])
  b <- b[b < end]
  data.frame(
    bucket = zenodo_bucket_label(as.character(b), interval),
    from = c(cfg$from %||% NA_character_, as.character(b[-1])),
    to = c(as.character(b[-1]), cfg$to %||% NA_character_)
  )
}
