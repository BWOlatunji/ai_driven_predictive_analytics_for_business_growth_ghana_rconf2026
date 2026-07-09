# Package -----------------------------------------------------------

required_packages <- c(
  "tidyverse",
  "tidymodels",
  "ranger",
  "xgboost",
  "pointblank",
  "skimr",
  "janitor",
  "here",
  "fs",
  "glue",
  "readr",
  "yardstick",
  "workflows",
  "workflowsets",
  "tune",
  "doParallel",
  "foreach",
  "mlflow",
  "targets",
  "tarchetypes",
  "jsonlite",
  "httr",
  "knitr",
  "scales",
  "quarto"
)

check_required_packages <- function(packages = required_packages) {
  missing_packages <- purrr::keep(
    packages,
    ~ !requireNamespace(.x, quietly = TRUE)
  )

  if (length(missing_packages) > 0) {
    stop(
      "The following packages are missing: ",
      paste(missing_packages, collapse = ", "),
      "\nRun source('scripts/00_setup.R') first, then rerun the workshop lifecycle.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

quietly_attach_package <- function(package) {
  suppressPackageStartupMessages(
    suppressWarnings(
      library(package, character.only = TRUE)
    )
  )

  invisible(TRUE)
}

load_required_packages <- function(packages = required_packages) {
  check_required_packages(packages)
  purrr::walk(packages, quietly_attach_package)
  invisible(TRUE)
}
