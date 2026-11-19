# Zenodo search for records created in [from, to). NULL = open-ended.
zenodo_query <- function(from = NULL, to = NULL) {
  b <- \(x) if (is.null(x)) "*" else sprintf('"%s"', x)
  sprintf("created:[%s TO %s}", b(from), b(to))
}
