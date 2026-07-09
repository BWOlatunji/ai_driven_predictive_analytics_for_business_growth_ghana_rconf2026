# complete workflow -----------------------------------------------

source("R/00_packages.R")
load_required_packages()

source("config/project_config.R")
source("R/utils.R")
source("R/01_import.R")
source("R/02_validate.R")
source("R/03_prepare_features.R")
source("R/04_split_recipe.R")
source("R/05_train_models.R")
source("R/06_evaluate_rank.R")
source("R/07_log_artifacts.R")

create_project_dirs()

mode <- "complete"
cl <- start_parallel_backend(max_cores = 2)

tryCatch(
  {
    houses_raw <- import_raw_housing_data()
    validate_housing_data(houses_raw)
    houses_clean <- clean_housing_data(houses_raw)
    houses_features <- prepare_housing_features(houses_clean)

    split_recipe <- create_data_split_and_recipe(houses_features, mode = mode)
    training_results <- train_and_tune_models(
      split_obj = split_recipe$split,
      house_recipe = split_recipe$recipe,
      folds = split_recipe$folds,
      mode = mode
    )

    ranking_results <- collect_model_metrics(training_results)
    evaluation_artifacts <- create_evaluation_artifacts(
      training_results = training_results,
      split_obj = split_recipe$split,
      ranking_results = ranking_results
    )

    write_run_manifest(mode = mode, ranking_results = ranking_results)
    render_stakeholder_report()

    log_step("Workshop lifecycle completed successfully.")
  },
  finally = {
    stop_parallel_backend(cl)
  }
)
