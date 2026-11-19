# README.md with the last successful run and simple stats per config entry.
write_readme <- function(cfgs, collection_dirs, file = Sys.getenv("ZOC_README", "README.md"),
                         title = Sys.getenv("ZOC_TITLE", "OpenAlex Collections")) {
  rows <- vapply(names(cfgs), \(name) {
    cfg <- cfgs[[name]]
    d <- zenodo_id_table(file.path("output", name, "zenodo"),
                         c("conceptdoi", "doi", "version_index"))
    dep <- zenodo_deposit(d$conceptdoi, d$doi)
    first <- is.na(d$version_index) | d$version_index == 0
    z <- list(records = nrow(d), concepts = length(unique(dep)),
              first = length(unique(dep[first])))
    col <- jsonlite::read_json(
      file.path("output", name, paste0(cfg$collection_name, ".collection"), "_collection.json")
    )
    range <- paste(cfg$from %||% "start", "–", cfg$to %||% "now")
    check <- zenodo_interval(cfg)
    if (!is.null(cfg$recheck)) {
      rc_file <- file.path("output", name, "zenodo_recheck.json")
      st <- if (file.exists(rc_file)) jsonlite::read_json(rc_file) else list()
      check <- if (!is.null(cfg$recheck$per_run)) {
        sprintf("%s; rolling recheck by %s, %d per run (last %s on %s)", check,
                cfg$recheck$interval, as.integer(cfg$recheck$per_run),
                st$last %||% "–", st$date %||% "–")
      } else {
        sprintf("%s; by %s every %s (last %s)", check, cfg$recheck$interval,
                cfg$recheck$every, st$date %||% "–")
      }
    }
    ch_file <- file.path("output", name, "zenodo_changes.json")
    change <- if (file.exists(ch_file)) {
      ch <- jsonlite::read_json(ch_file)
      sprintf("%s: +%d / −%d deposits (+%d / −%d records)", ch$date,
              ch$added_deposits, ch$removed_deposits, ch$added_records, ch$removed_records)
    } else "–"
    sprintf(
      "| %s | [%s](https://zenodo.org/communities/%s) | %s | %s | %d | %d | %d | %d | %s | [%s](%s) | %s |",
      name, cfg$zenodo_community, cfg$zenodo_community, range, check,
      z$records, z$concepts, z$first, col$member_count, change,
      col$collection_id, col$collection_url, col$access
    )
  }, "")
  writeLines(c(
    paste("#", title),
    "",
    "OpenAlex collections of the deposits in Zenodo communities, updated by [zenodo-openalex-collection](https://github.com/rkrug/zenodo-openalex-collection).",
    "",
    sprintf("**Last successful run:** %s UTC (pipeline runtime %.1f min)",
            format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"),
            proc.time()[["elapsed"]] / 60), # elapsed time of the R process running tar_make()
    "",
    "| Config | Zenodo community | Created | Check interval; recheck | Zenodo records (all versions) | Deposits with a version in range | Deposits first created in range | OpenAlex works | Last change on Zenodo | Collection | Access |",
    "|---|---|---|---|---:|---:|---:|---:|---|---|---|",
    rows,
    "",
    "## How it works",
    "",
    "A [targets](https://docs.ropensci.org/targets/) pipeline from [zenodo-openalex-collection](https://github.com/rkrug/zenodo-openalex-collection), one set of targets per entry in `config.yml`:",
    "",
    "1. `zenodo_check_<name>`: counts the community's records (all versions) on Zenodo for each month of the range (1 request per month) and compares them with the downloaded months.",
    "2. `zenodo_ids_<name>`: downloads only the months whose counts changed, as parquet files of at most 10,000 records (`output/<name>/zenodo/<YYYY-MM>/`).",
    "3. `openalex_collection_<name>`: builds the OpenAlex collection with [openalexPro](https://openalexpro.r-universe.dev) from the concept DOIs (they resolve to the newest version) of the deposits whose first version was created in the range, searching all OpenAlex corpora (core + expansion).",
    "",
    "The data (`output/`) and the targets store (`_targets/`) are kept in the latest `data-*` release, not in git. Each run restores them from there and publishes a new release only when `output/` changed (the 3 newest are kept).",
    "",
    "Setup and local runs: see [zenodo-openalex-collection](https://github.com/rkrug/zenodo-openalex-collection#readme)."
  ), file)
  file
}
