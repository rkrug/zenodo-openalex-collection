# Writes all records created in [from, to) as parquet files of at most `chunk` records
# into `dir` and returns the number of records written. Only one chunk is held in memory.
# Zenodo returns at most 10,000 results per search, so larger ranges are halved until
# each piece fits; files are named <from>_<to>_<n>.parquet after their piece.
# `n`: the number of records if already known (saves a count request).
fetch_zenodo_range <- function(cfg, dir, from = NULL, to = NULL, limit = 10000, chunk = 10000,
                               n = NULL) {
  q <- zenodo_query(from, to)
  n <- n %||% zenodo_count(cfg, q)
  if (n >= limit) {
    t <- function(x, default) as.POSIXct(x %||% default, tz = "UTC")
    lo <- t(from, "2013-01-01") # Zenodo launch
    hi <- t(to, as.character(Sys.Date() + 1))
    if (difftime(hi, lo, units = "secs") < 1) stop("10,000+ records within one second: ", q)
    mid <- format(lo + (hi - lo) / 2, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
    return(fetch_zenodo_range(cfg, dir, from, mid, limit, chunk) +
           fetch_zenodo_range(cfg, dir, mid, to, limit, chunk))
  }
  if (n == 0) return(0)
  size <- if (nzchar(api_key("API_zenodo_ro"))) 100 else 25 # anonymous max is 25
  clean <- \(x) gsub("[^0-9A-Za-z-]", "", x)
  stem <- paste(clean(from %||% "start"), clean(to %||% "now"), sep = "_")
  hits <- list()
  written <- 0
  part <- 0
  flush <- function() {
    if (!length(hits)) return()
    part <<- part + 1
    arrow::write_parquet(zenodo_records(hits), file.path(dir, sprintf("%s_%03d.parquet", stem, part)))
    written <<- written + length(hits)
    hits <<- list()
  }
  res <- zenodo_get(zenodo_url(cfg), allversions = "true", size = size, sort = "oldest", q = q)
  repeat {
    hits <- c(hits, res$hits$hits)
    message(q, ": ", written + length(hits), " / ", res$hits$total)
    if (length(hits) >= chunk) flush()
    if (is.null(res$links[["next"]])) break
    res <- zenodo_get(res$links[["next"]])
  }
  flush()
  stopifnot(written == res$hits$total)
  written
}
