library(targets)
library(tarchetypes)
tar_option_set(packages = "openalexPro")

# Run from the folder with the config (the community repo). The code may live elsewhere:
# ZOC_CODE_DIR = folder of this repo (default: current folder),
# ZOC_CONFIG   = config file (default: config.yml).
tar_source(file.path(Sys.getenv("ZOC_CODE_DIR", "."), "R"))

cfgs <- yaml::read_yaml(Sys.getenv("ZOC_CONFIG", "config.yml")) # errors on duplicate names
dup <- \(x) unique(x[duplicated(x)])
coll <- vapply(cfgs, \(x) x$collection_name %||% NA_character_, "")
if (anyNA(coll)) stop("Missing collection_name in: ", toString(names(cfgs)[is.na(coll)]))
if (length(d <- dup(coll))) stop("Duplicate collection_name: ", toString(d))

mapped <- tar_map(
  unlist = FALSE,
  values = list(name = names(cfgs), cfg = unname(cfgs)),
  names = "name",
  tar_target(
    zenodo_check,
    check_zenodo(cfg, file.path("output", name, "zenodo")),
    cue = tar_cue("always")
  ),
  tar_target(
    zenodo_ids,
    fetch_zenodo(cfg, zenodo_check, file.path("output", name, "zenodo")),
    format = "file"
  ),
  tar_target(
    openalex_collection,
    create_collection(cfg, zenodo_ids, file.path("output", name)),
    format = "file"
  )
)

list(
  mapped,
  tar_combine(
    readme,
    mapped[["openalex_collection"]],
    command = write_readme(cfgs, c(!!!.x)),
    format = "file",
    cue = tar_cue("always")
  )
)
