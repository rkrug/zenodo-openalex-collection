zenodo_url <- function(cfg) {
  sprintf("https://zenodo.org/api/communities/%s/records", cfg$zenodo_community)
}
