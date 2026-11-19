create_collection <- function(cfg, ids_dir, folder) {
  # Concept DOIs: always resolve to the newest version; OpenAlex uses them as the
  # main DOI of the merged work.
  # Each deposit belongs to the range in which its first version (index 0) was created,
  # so deposits with versions in several ranges are in exactly one collection.
  concepts <- arrow::open_dataset(ids_dir) |>
    dplyr::filter(version_index == 0) |>
    dplyr::distinct(conceptdoi) |>
    dplyr::collect()
  # corpus = "all": core + expansion. Most Zenodo deposits are only in the expansion.
  q <- pro_query(
    doi = sort(na.omit(concepts$conceptdoi)),
    chunk_limit = 500,
    options = list(corpus = "all")
  )
  pro_collection(
    q,
    select = c("id", "doi"),
    refresh = TRUE,
    name = cfg$collection_name,
    project_folder = folder,
    verbose = TRUE,
    api_key = api_key("API_openalex_personal"),
    access = cfg$access %||% "private"
  )
}
