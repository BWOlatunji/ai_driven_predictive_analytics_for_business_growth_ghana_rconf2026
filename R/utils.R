# Utility functions -----------------------------------------------------------

create_project_dirs <- function() {
  dirs <- c(
    "data/raw",
    "data/interim",
    "data/processed",
    "data/new",
    "artifacts/metrics",
    "artifacts/models",
    "artifacts/model_package",
    "artifacts/predictions",
    "artifacts/figures",
    "artifacts/reports",
    "artifacts/governance",
    "artifacts/mlflow",
    "artifacts/logs",
    "mlruns"
  )

  purrr::walk(dirs, ~ fs::dir_create(here::here(.x)))
  invisible(dirs)
}

log_step <- function(message) {
  cat(glue::glue("\n[{format(Sys.time(), '%Y-%m-%d %H:%M:%S')}] {message}\n"))
}

safe_divide <- function(numerator, denominator) {
  numerator / pmax(denominator, 1)
}

winsorize_numeric <- function(x, lower = 0.001, upper = 0.999) {
  limits <- stats::quantile(x, probs = c(lower, upper), na.rm = TRUE)
  pmin(pmax(x, limits[[1]]), limits[[2]])
}

save_csv_artifact <- function(data, path) {
  readr::write_csv(data, path)
  log_step(glue::glue("Saved CSV artifact: {path}"))
  invisible(path)
}

save_rds_artifact <- function(object, path) {
  saveRDS(object, path)
  log_step(glue::glue("Saved RDS artifact: {path}"))
  invisible(path)
}

save_plot_artifact <- function(plot, path, width = 9, height = 6, dpi = 150) {
  ggplot2::ggsave(filename = path, plot = plot, width = width, height = height, dpi = dpi)
  log_step(glue::glue("Saved plot artifact: {path}"))
  invisible(path)
}

start_parallel_backend <- function(max_cores = 2) {
  available <- parallel::detectCores(logical = TRUE)
  cores_to_use <- max(1, min(max_cores, available, na.rm = TRUE))
  cl <- parallel::makePSOCKcluster(cores_to_use)
  doParallel::registerDoParallel(cl)
  log_step(glue::glue("Parallel backend registered with {cores_to_use} core(s)."))
  cl
}

stop_parallel_backend <- function(cl) {
  if (!is.null(cl)) {
    parallel::stopCluster(cl)
    foreach::registerDoSEQ()
    log_step("Parallel backend stopped.")
  }
  invisible(TRUE)
}
