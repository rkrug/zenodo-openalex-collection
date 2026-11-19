# Key from env var `name` (e.g. on CI), else from the system keyring service `name`, else "".
api_key <- function(name) {
  key <- Sys.getenv(name)
  if (!nzchar(key) && requireNamespace("keyring", quietly = TRUE)) {
    key <- tryCatch(keyring::key_get(name), error = \(e) "")
  }
  key
}
