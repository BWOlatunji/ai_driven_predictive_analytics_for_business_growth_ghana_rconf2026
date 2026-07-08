# Logs the workshop runs to MLflow.

source("scripts/00_setup.R")
source("R/08_mlflow_tracking.R")

log_metrics_params_to_mlflow(
  experiment_name = "ghana-r-2026-real-estate-market-intelligence"
)
