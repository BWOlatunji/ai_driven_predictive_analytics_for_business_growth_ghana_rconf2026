# Reproducible pipeline with targets --------------------------------------
#
library(targets)
library(tarchetypes)
library(quarto)

source("config/project_config.R")
tar_source()

tar_option_set(packages = c(
  "tidyverse", "tidymodels", "pointblank", "vip", "readr", "fs", "glue",
  "here", "janitor", "skimr", "ranger", "xgboost", "doParallel", "quarto", "httr", "jsonlite"
))

list(
  # Adding setting for Workshop -------------------------------------------------------------
  tar_target(mode, "fast"),

  # Data loading and validation steps ----------------------------------------------
  tar_target(raw_data, import_raw_housing_data()),
  tar_target(validation_report, validate_housing_data(raw_data)),
  tar_target(clean_data, clean_housing_data(raw_data)),
  tar_target(feature_data, prepare_housing_features(clean_data)),

  # Step where split, recipes, training, and evaluation ---------------------------------
  tar_target(split_bundle, create_data_split_and_recipe(feature_data, mode = mode)),
  tar_target(
    training_results,
    train_and_tune_models(
      split_obj = split_bundle$split,
      house_recipe = split_bundle$recipe,
      folds = split_bundle$folds,
      mode = mode
    )
  ),
  tar_target(ranking_results, collect_model_metrics(training_results)),
  tar_target(
    evaluation_artifacts,
    create_evaluation_artifacts(
      training_results = training_results,
      split_obj = split_bundle$split,
      ranking_results = ranking_results
    )
  ),

  # Generating reports --------------------------------------------------
  tar_target(run_manifest, write_run_manifest(mode = mode, ranking_results = ranking_results)),
  tar_target(mlflow_run, log_metrics_params_to_mlflow()),
  tar_quarto(report, path = "report.qmd"),
 
  # Demonstrate rep... ------------------------------------------------
  tar_target(model_package, package_best_model()),
  
  tar_target(
    scored_new_properties,
    {
      model_package
      score_new_properties()
    }
  )
)
