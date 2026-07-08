# Start a local MLflow server without Docker ---------------------------------
# Optional. The core workshop workflow can run without MLflow; in that case
# scripts/03_run_mlflow_tracking.R writes a local fallback ledger.
#
# To use this script, install the Python MLflow CLI first:
#   python -m pip install mlflow
#
# Then run this script from the R console and keep the R session open.

source("scripts/00_setup.R")

fs::dir_create(here::here("mlruns"))
fs::dir_create(here::here("artifacts", "mlflow"))
fs::dir_create(here::here("artifacts", "logs"))

backend_db <- normalizePath(here::here("mlruns", "mlflow.db"), winslash = "/", mustWork = FALSE)
artifact_root <- normalizePath(here::here("artifacts", "mlflow"), winslash = "/", mustWork = FALSE)
log_file <- here::here("artifacts", "logs", "mlflow_server.log")

Sys.setenv(MLFLOW_TRACKING_URI = "http://127.0.0.1:5001")

mlflow_cmd <- Sys.which("mlflow")
python_cmd <- Sys.which("python")

if (nzchar(mlflow_cmd)) {
  cmd <- mlflow_cmd
  args <- c(
    "server",
    "--backend-store-uri", paste0("sqlite:///", backend_db),
    "--default-artifact-root", paste0("file:///", artifact_root),
    "--host", "127.0.0.1",
    "--port", "5001"
  )
} else if (nzchar(python_cmd)) {
  cmd <- python_cmd
  args <- c(
    "-m", "mlflow", "server",
    "--backend-store-uri", paste0("sqlite:///", backend_db),
    "--default-artifact-root", paste0("file:///", artifact_root),
    "--host", "127.0.0.1",
    "--port", "5001"
  )
} else {
  stop(
    "Neither the mlflow command nor python was found on PATH. ",
    "Install Python and MLflow first: python -m pip install mlflow",
    call. = FALSE
  )
}

log_step("Starting local MLflow server at http://127.0.0.1:5001")
log_step(glue::glue("MLflow logs will be written to: {log_file}"))

if (.Platform$OS.type == "windows") {
  system2(cmd, args, stdout = log_file, stderr = log_file, wait = FALSE)
} else {
  system2(cmd, args, stdout = log_file, stderr = log_file, wait = FALSE)
}

message("Open http://127.0.0.1:5001 in your browser. If it does not open immediately, wait 10-20 seconds and refresh.")
message("Then run: source('scripts/03_run_mlflow_tracking.R')")
