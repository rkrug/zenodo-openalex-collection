# Interval label of Zenodo `created` timestamps (or dates): "2024-03", "2024-Q1", "2024", "all".
zenodo_bucket_label <- function(x, interval = "month") {
  switch(interval,
    month = substr(x, 1, 7),
    quarter = paste0(substr(x, 1, 4), "-Q", (as.integer(substr(x, 6, 7)) - 1) %/% 3 + 1),
    year = substr(x, 1, 4),
    all = rep("all", length(x))
  )
}
