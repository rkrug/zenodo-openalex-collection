# Sends the Zenodo token API_zenodo_ro when available (allows 100 records per page).
# Zenodo allows 30 search requests per minute (also with a token): evenly spaced at one
# request per 2.2 s (~27/min); a 429 waits until Zenodo's rate limit window resets.
zenodo_get <- function(url, ...) {
  req <- httr2::request(url) |>
    httr2::req_url_query(...) |>
    httr2::req_throttle(capacity = 1, fill_time_s = 2.2, realm = "zenodo") |>
    httr2::req_retry(
      max_tries = 5,
      is_transient = \(r) httr2::resp_status(r) %in% c(429, 500, 502, 503, 504),
      after = \(r) {
        reset <- suppressWarnings(as.numeric(httr2::resp_header(r, "x-ratelimit-reset")))
        if (httr2::resp_status(r) == 429 && length(reset) && !is.na(reset)) {
          max(1, reset - as.numeric(Sys.time()) + 1)
        } else NA # default backoff
      }
    ) |>
    httr2::req_error(body = \(r) httr2::resp_body_string(r))
  token <- api_key("API_zenodo_ro")
  if (nzchar(token)) req <- httr2::req_auth_bearer_token(req, token)
  req |>
    httr2::req_perform() |>
    httr2::resp_body_json()
}
