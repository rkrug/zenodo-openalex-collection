# Monthly buckets [from, to) covering the config's range. NA = open end
# (from: before Zenodo's launch in 2013, to: until now).
zenodo_months <- function(cfg) {
  day <- \(x) as.Date(substr(x, 1, 10))
  start <- day(cfg$from %||% "2013-01-01")
  end <- day(cfg$to %||% as.character(Sys.Date() + 1))
  m <- seq(as.Date(format(start, "%Y-%m-01")), end, by = "month")
  m <- m[m < end]
  data.frame(
    month = format(m, "%Y-%m"),
    from = c(cfg$from %||% NA_character_, as.character(m[-1])),
    to = c(as.character(m[-1]), cfg$to %||% NA_character_)
  )
}
