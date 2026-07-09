# Going through the workflow using targets ----------------------------


source("scripts/00_setup.R")

if (!requireNamespace("targets", quietly = TRUE)) {
  stop("Package 'targets' is required. Install it with install.packages('targets').", call. = FALSE)
}

targets::tar_make()
