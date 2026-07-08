# Project configuration -------------------------------------------------------
# Edit these values if you want to adapt the workflow to another African market
# dataset or another conference environment.

project_name <- "AI-Driven Predictive Analytics for Business Growth Using R"
use_case_name <- "Nigeria Real Estate Market Intelligence"
experiment_name <- "ghana-r-2026-real-estate-growth"

raw_data_path <- here::here("data", "raw", "nigeria_houses_data.csv")
interim_data_path <- here::here("data", "interim", "houses_imported.csv")
processed_data_path <- here::here("data", "processed", "houses_model_ready.csv")

target_column <- "price"
model_target <- "log_price"

artifact_dirs <- list(
  metrics = here::here("artifacts", "metrics"),
  models = here::here("artifacts", "models"),
  predictions = here::here("artifacts", "predictions"),
  figures = here::here("artifacts", "figures"),
  reports = here::here("artifacts", "reports")
)
