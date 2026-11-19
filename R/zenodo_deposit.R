# Deposit identifier of Zenodo records: the concept DOI (all versions of a deposit), or,
# for records without one (older records, or records with a publisher DOI), the record's
# own DOI.
zenodo_deposit <- function(conceptdoi, doi) {
  ifelse(is.na(conceptdoi) | conceptdoi == "", doi, conceptdoi)
}
