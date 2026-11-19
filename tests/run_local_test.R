# Local test of the pipeline on tests/config.yml (a small range in a test collection).
#
# Usage, from the root of this repository:
#   source("tests/run_local_test.R")   # defines run_local_test() and runs it once
#   run_local_test(full = TRUE)        # full re-download (like the checkbox on GitHub)
#   run_local_test(fresh = TRUE)       # start from scratch (deletes tests/run/)
#
# Output, targets store and README go to tests/run/ (ignored by git) and are kept between
# runs, so repeated runs test the incremental behaviour.
# Keys: the Zenodo token from env var or keyring entry API_zenodo_ro; the OpenAlex key of
# the test account from `openalex_key` (env var or keyring entry), so the test collection
# is created there and not in your personal account.
run_local_test <- function(
  full = FALSE,
  fresh = FALSE,
  openalex_key = "API_openalex_github_test"
) {
  repo <- normalizePath(".")
  if (
    !file.exists(file.path(repo, "_targets.R")) ||
      !dir.exists(file.path(repo, "tests"))
  ) {
    stop("Run from the root of the zenodo-openalex-collection repository.")
  }
  key <- Sys.getenv(openalex_key)
  if (!nzchar(key)) {
    key <- keyring::key_get(openalex_key)
  }

  work <- file.path(repo, "tests", "run")
  if (fresh) {
    unlink(work, recursive = TRUE)
  }
  dir.create(work, recursive = TRUE, showWarnings = FALSE)

  env <- c(
    ZOC_CODE_DIR = repo,
    ZOC_CONFIG = file.path(repo, "tests", "config.yml"),
    ZOC_TITLE = "Test",
    ZOC_README = "README.md",
    ZOC_FULL = if (full) "true" else "",
    API_openalex_personal = key
  )
  old_env <- Sys.getenv(names(env), unset = NA)
  old_wd <- setwd(work)
  on.exit(
    {
      setwd(old_wd)
      unset <- is.na(old_env)
      if (any(unset)) {
        Sys.unsetenv(names(old_env)[unset])
      }
      if (any(!unset)) do.call(Sys.setenv, as.list(old_env[!unset]))
    },
    add = TRUE
  )
  do.call(Sys.setenv, as.list(env))

  targets::tar_make(script = file.path(repo, "_targets.R"))
  cat("\n", readLines("README.md")[1:12], sep = "\n")
  invisible(work)
}

run_local_test()
