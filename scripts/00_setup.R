# Local workshop setup --------------------------------------------------------
# Run this once after cloning the repository, especially when running locally
# without Docker.

options(repos = c(CRAN = "https://cloud.r-project.org"))

source("R/00_packages.R")

install_if_missing <- function(packages) {
  missing_packages <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(missing_packages) > 0) {
    message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
    install.packages(missing_packages, dependencies = TRUE)
  } else {
    message("All required R packages are already installed.")
  }

  invisible(missing_packages)
}

install_if_missing(required_packages)

# Load only after installation has completed.
load_required_packages()

source("config/project_config.R")
source("R/utils.R")
create_project_dirs()


if (requireNamespace("quarto", quietly = TRUE)) {
  qpath <- tryCatch(quarto::quarto_path(), error = function(e) "")
  if (!nzchar(qpath)) {
    warning(
      "The Quarto CLI was not detected. The modelling workflow can still run, ",
      "but report rendering may fail until Quarto Desktop is installed.",
      call. = FALSE
    )
  }
}

message("Setup complete. You can now run source('scripts/01_run_complete_workshop.R').")
