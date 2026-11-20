create_collection <- function(cfg, ids_dir, folder) {
  # Deposits: concept DOIs (always resolve to the newest version; OpenAlex uses them as
  # the main DOI of the merged work), or the record's own DOI for records without one
  # (older records, records with a publisher DOI).
  # Each deposit belongs to the range in which its first version (index 0) was created,
  # so deposits with versions in several ranges are in exactly one collection; records
  # without version information count as first versions.
  z <- zenodo_id_table(ids_dir, c("conceptdoi", "doi", "version_index"))
  z <- z[is.na(z$version_index) | z$version_index == 0, ]
  deposits <- unique(zenodo_deposit(z$conceptdoi, z$doi))
  deposits <- deposits[!is.na(deposits) & deposits != ""]
  # an empty DOI filter would match all of OpenAlex
  if (!length(deposits)) stop("No Zenodo deposits in ", ids_dir, "; not creating the collection.")
  # corpus = "all": core + expansion. Most Zenodo deposits are only in the expansion.
  q <- pro_query(
    doi = sort(deposits),
    chunk_limit = 500,
    options = list(corpus = "all")
  )
  pro_collection(
    q,
    select = cfg$openalex_select %||% c("id", "doi"), # config `openalex_select`: "id", "all" or fields
    refresh = TRUE,
    name = cfg$collection_name,
    project_folder = folder,
    verbose = TRUE,
    api_key = api_key("API_openalex_personal"),
    access = cfg$access %||% "private"
  )
}
