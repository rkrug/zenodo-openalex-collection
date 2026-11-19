zenodo_count <- function(cfg, q) {
  zenodo_get(zenodo_url(cfg), allversions = "true", size = 1, q = q)$hits$total
}
