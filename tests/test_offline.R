# Offline checks of the pipeline logic: no network, no keys, nothing outside tempdir().
# Zenodo is replaced by a fake that serves records from a local table.
# Run from the root of this repository: Rscript tests/test_offline.R
# Runs on GitHub for every push and pull request to main and dev (.github/workflows/check.yml).

e <- new.env()
for (f in list.files("R", "[.]R$", full.names = TRUE)) sys.source(f, e)
err <- \(expr) inherits(try(expr, silent = TRUE), "try-error")
ok <- \(name) cat("ok  ", name, "\n")

# --- intervals --------------------------------------------------------------------------
with(e, {
  stopifnot(
    zenodo_bucket_label("2024-12-30T10:00:00", "week") == "2025-W01",
    zenodo_bucket_label("2024-05-10", "month") == "2024-05",
    zenodo_bucket_label("2024-05-10", "quarter") == "2024-Q2",
    zenodo_bucket_label("2024-05-10", "year") == "2024",
    zenodo_bucket_label(c("2024-05-10", "2020-01-01"), "all") == "all",
    identical(zenodo_bucket_start(c("2025-W01", "2024-05", "2024-Q2", "2024", "all")),
              c("2024-12-30", "2024-05-01", "2024-04-01", "2024-01-01", NA))
  )
  # round trip label -> start -> label
  for (iv in c("week", "month", "quarter", "year")) {
    d <- as.character(seq(as.Date("2019-12-20"), as.Date("2021-01-10"), by = "day"))
    lab <- unique(zenodo_bucket_label(d, iv))
    stopifnot(identical(zenodo_bucket_label(zenodo_bucket_start(lab), iv), lab))
  }
  b <- zenodo_buckets(list(from = "2024-01-15", to = "2024-04-01", interval = "month"))
  stopifnot(
    identical(b$bucket, c("2024-01", "2024-02", "2024-03")),
    identical(b$from, c("2024-01-15", "2024-02-01", "2024-03-01")),
    identical(b$to, c("2024-02-01", "2024-03-01", "2024-04-01"))
  )
  w <- zenodo_buckets(list(from = "2025-01-01", to = "2025-01-20", interval = "week"))
  stopifnot(identical(w$bucket, c("2025-W01", "2025-W02", "2025-W03")), w$from[1] == "2025-01-01")
  stopifnot(identical(zenodo_buckets(list(interval = "all"))$bucket, "all"))
  y <-zenodo_buckets(list(from = "2023-06-01", interval = "year"))
  stopifnot(y$bucket[1] == "2023", is.na(y$to[nrow(y)]))
})
ok("interval labels, starts and buckets")

# --- overlaps and recheck -----------------------------------------------------------------
with(e, {
  storage <- data.frame(bucket = c("2024-01", "2024-02", "2024-03"),
                        from = c("2024-01-01", "2024-02-01", "2024-03-01"),
                        to = c("2024-02-01", "2024-03-01", NA))
  wk <- data.frame(bucket = "2024-W05", from = "2024-01-29", to = "2024-02-05")
  stopifnot(identical(zenodo_overlaps(wk, storage), c("2024-01", "2024-02")))
  late <- data.frame(bucket = "x", from = "2030-01-01", to = NA)
  stopifnot(identical(zenodo_overlaps(late, storage), "2024-03"))
  stopifnot(length(zenodo_overlaps(wk[0, ], storage)) == 0)

  fine <- data.frame(bucket = paste0("b", 1:5))
  stopifnot(
    identical(recheck_select(fine, 2)$bucket, c("b1", "b2")),
    identical(recheck_select(fine, 2, "b2")$bucket, c("b3", "b4")),
    identical(recheck_select(fine, 2, "b5")$bucket, c("b1", "b2")),
    identical(recheck_select(fine, 2, "b4")$bucket, c("b5", "b1")),
    identical(recheck_select(fine, 2, "gone")$bucket, c("b1", "b2")),
    identical(recheck_select(fine, 9)$bucket, fine$bucket),
    identical(recheck_select(fine)$bucket, fine$bucket),
    is.data.frame(recheck_select(fine, 1))
  )

  f <- tempfile(fileext = ".json")
  stopifnot(!recheck_due(list(), f), recheck_due(list(recheck = list(per_run = 2)), f),
            recheck_due(list(recheck = list(every = "month")), f))
  jsonlite::write_json(list(date = "2026-01-15"), f, auto_unbox = TRUE)
  m <- list(recheck = list(every = "month"))
  stopifnot(!recheck_due(m, f, as.Date("2026-02-14")), recheck_due(m, f, as.Date("2026-02-15")))
})
ok("overlaps, recheck selection and due dates")

# --- deposits -----------------------------------------------------------------------------
with(e, {
  stopifnot(identical(
    zenodo_deposit(c("10.5281/zenodo.1", NA, ""), c("10.5281/zenodo.2", "10.1/b", "10.1/c")),
    c("10.5281/zenodo.1", "10.1/b", "10.1/c")
  ))
  # never an empty DOI filter (it would match all of OpenAlex)
  msg <- tryCatch(create_collection(list(), file.path(tempdir(), "empty"), tempdir()),
                  error = conditionMessage)
  stopifnot(grepl("^No Zenodo deposits", msg))
})
ok("deposits and the empty-collection guard")

# --- range download with a fake Zenodo ------------------------------------------------------
# Fake records: `created` timestamps; zenodo_get() answers count (size = 1) and paged
# searches for `created:[from TO to}` from them.
fake_zenodo <- function(created) {
  force(created)
  bound <- \(x, open) if (x == "*") open else gsub('"', "", x)
  sel <- function(q) {
    m <- regmatches(q, regexec('created:\\[(\\*|"[^"]*") TO (\\*|"[^"]*")\\}', q))[[1]]
    t <- \(x) as.POSIXct(x, tz = "UTC", tryFormats = c("%Y-%m-%dT%H:%M:%OS", "%Y-%m-%d"))
    lo <- t(bound(m[2], "1900-01-01")); hi <- t(bound(m[3], "2999-01-01"))
    ct <- t(created)
    which(ct >= lo & ct < hi)
  }
  calls <- 0
  get <- function(url, ..., size = 25, q = NULL, page = 1) {
    calls <<- calls + 1
    if (calls > 5000) stop("fake Zenodo: too many requests (endless bisection?)")
    if (startsWith(url, "fake:")) { # next page link: fake:<page>:<size>:<q>
      p <- strsplit(sub("^fake:", "", url), ":", fixed = TRUE)[[1]]
      page <- as.integer(p[1]); size <- as.integer(p[2]); q <- paste(p[-(1:2)], collapse = ":")
    }
    i <- sel(q)
    rows <- i[seq_along(i) > (page - 1) * size & seq_along(i) <= page * size]
    hits <- lapply(rows, \(r) list(id = r, doi = paste0("10.5281/zenodo.", r),
                                   conceptdoi = paste0("10.5281/zenodo.c", r),
                                   created = format(as.POSIXct(created[r], tz = "UTC"),
                                                    "%Y-%m-%dT%H:%M:%OS+00:00")))
    nxt <- if (page * size < length(i)) sprintf("fake:%d:%d:%s", page + 1, size, q)
    list(hits = list(total = length(i), hits = hits), links = list(`next` = nxt))
  }
  list(get = get, calls = \() calls)
}

run_range <- function(created, from, to, limit, chunk = 50) {
  z <- fake_zenodo(created)
  e$zenodo_get <- z$get
  e$api_key <- \(name) "" # anonymous: 25 per page
  dir <- tempfile("range")
  dir.create(dir)
  n <- suppressMessages(e$fetch_zenodo_range(list(zenodo_community = "x"), dir, from, to,
                                             limit = limit, chunk = chunk))
  d <- e$zenodo_id_table(dir, c("id", "created"))
  list(n = n, ids = sort(as.integer(d$id)), files = list.files(dir), calls = z$calls())
}

# 400 records within one day, 50 of them in the same minute: needs bisection to sub-hour
# pieces, i.e. split points with a time (the bug: the time was dropped -> endless recursion)
set.seed(1)
day <- as.POSIXct("2017-02-08", tz = "UTC")
created <- format(c(day + sort(runif(350, 0, 86399)), day + 43200 + 0:49), "%Y-%m-%dT%H:%M:%S")
r <- run_range(created, "2017-02-01", "2017-03-01", limit = 100)
stopifnot(r$n == 400, identical(r$ids, seq_along(created)), r$calls < 200,
          any(grepl("T[0-9]{6}_", r$files)))
ok(sprintf("bisection of a dense day: %d records, %d files, %d requests", r$n, length(r$files), r$calls))

# open range (from/to NULL) and chunking into files of at most `chunk` records
# (files are cut at page boundaries: 25 records per page here)
r <- run_range(created[1:90], NULL, NULL, limit = 100, chunk = 25)
stopifnot(r$n == 90, identical(r$ids, 1:90),
          identical(r$files, sprintf("start_now_%03d.parquet", 1:4)))
ok("open range and chunked files")

# more than `limit` records within one second: a clear error, not endless recursion
stopifnot(err(run_range(rep("2017-02-08T12:00:00", 150), "2017-02-08", "2017-02-09", limit = 100)))
ok("10,000+ records within one second stops")

# --- config validation in _targets.R -----------------------------------------------------
validate <- function(yml) {
  f <- tempfile(fileext = ".yml")
  writeLines(yml, f)
  old <- Sys.getenv(c("ZOC_CONFIG", "ZOC_CODE_DIR"), unset = NA)
  on.exit(for (n in names(old)) {
    if (is.na(old[[n]])) Sys.unsetenv(n) else do.call(Sys.setenv, as.list(old[n]))
  })
  Sys.setenv(ZOC_CONFIG = f, ZOC_CODE_DIR = ".")
  !err(suppressMessages(source("_targets.R", local = new.env())))
}
entry <- \(...) c("a:", "  zenodo_community: x", paste0("  ", c(...)))
stopifnot(
  validate(entry("collection_name: A")),
  validate(entry("collection_name: A", "interval: month", "recheck:", "  interval: week", "  per_run: 2")),
  validate(entry("collection_name: A", "interval: year", "recheck:", "  interval: month", "  every: month")),
  validate(entry("collection_name: A", "openalex_select: [id, doi, title]")),
  validate(entry("collection_name: A", "openalex_select: all")),
  !validate(entry("collection_name: A", "openalex_select: 3")),
  !validate(entry("collection_name: A", "openalex_select: ['']")),
  !validate(entry("interval: month")), # no collection_name
  !validate(c(entry("collection_name: A"), "b:", "  zenodo_community: y", "  collection_name: A")),
  !validate(entry("collection_name: A", "interval: day")),
  !validate(entry("collection_name: A", "interval: month", "recheck:", "  interval: month", "  per_run: 2")),
  !validate(entry("collection_name: A", "interval: month", "recheck:", "  interval: week",
                  "  per_run: 2", "  every: month")),
  !validate(entry("collection_name: A", "interval: month", "recheck:", "  interval: week", "  per_run: 0")),
  !validate(entry("collection_name: A", "interval: month", "recheck:", "  interval: week", "  every: day"))
)
ok("config validation")

cat("All offline checks passed.\n")
