# Zenodo search hits -> one row per record (version).
zenodo_records <- function(hits) {
  chr <- \(f) vapply(hits, \(h) f(h) %||% NA_character_, "")
  ids <- data.frame(
    id = chr(\(h) as.character(h$id)),
    doi = chr(\(h) h$doi),
    conceptdoi = chr(\(h) h$conceptdoi),
    created = chr(\(h) h$created),
    title = chr(\(h) h$metadata$title),
    publication_date = chr(\(h) h$metadata$publication_date),
    resource_type = chr(\(h) h$metadata$resource_type$type),
    version = chr(\(h) h$metadata$version),
    access_right = chr(\(h) h$metadata$access_right),
    version_index = vapply(hits, \(h) h$metadata$relations$version[[1]]$index %||% NA_integer_, 1L),
    is_last = vapply(hits, \(h) h$metadata$relations$version[[1]]$is_last %||% NA, NA)
  )
  # One table per deposit (0 rows if none): identifier, relation, resource_type, scheme
  ids$related_identifiers <- lapply(hits, \(h) {
    r <- h$metadata$related_identifiers
    f <- \(k) vapply(r, \(x) x[[k]] %||% NA_character_, "")
    data.frame(identifier = f("identifier"), relation = f("relation"),
               resource_type = f("resource_type"), scheme = f("scheme"))
  })
  ids
}
