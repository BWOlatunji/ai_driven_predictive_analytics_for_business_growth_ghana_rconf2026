# Model training, resampling, tuning, and experiment logging ---------

emit_training_progress <- function(text) {
  if (exists("log_step", mode = "function")) {
    log_step(text)
  } else {
    message(text)
  }

  if (interactive()) {
    utils::flush.console()
  }

  invisible(TRUE)
}

collect_tuning_experiments <- function(tuning_results) {
  bind_rows_safe <- function(...) {
    items <- list(...)
    items <- purrr::compact(items)
    if (length(items) == 0) tibble::tibble() else dplyr::bind_rows(items)
  }

  linear_metrics <- tryCatch(
    tune::collect_metrics(tuning_results$tuning$linear) %>%
      dplyr::mutate(model = "linear_regression", experiment_type = "resampling_baseline"),
    error = function(e) tibble::tibble()
  )

  rf_metrics <- tryCatch(
    tune::collect_metrics(tuning_results$tuning$random_forest) %>%
      dplyr::mutate(model = "random_forest", experiment_type = "hyperparameter_tuning"),
    error = function(e) tibble::tibble()
  )

  xgb_metrics <- tryCatch(
    tune::collect_metrics(tuning_results$tuning$xgboost) %>%
      dplyr::mutate(model = "xgboost", experiment_type = "hyperparameter_tuning"),
    error = function(e) tibble::tibble()
  )

  experiments <- bind_rows_safe(linear_metrics, rf_metrics, xgb_metrics) %>%
    dplyr::relocate(model, experiment_type)

  experiments
}

write_hyperparameter_artifacts <- function(training_results) {
  fs::dir_create(here::here("artifacts", "metrics"))
  fs::dir_create(here::here("artifacts", "governance"))

  experiments <- collect_tuning_experiments(training_results)

  if (nrow(experiments) > 0) {
    readr::write_csv(experiments, here::here("artifacts", "metrics", "hyperparameter_experiments.csv"))
    readr::write_csv(experiments, here::here("artifacts", "governance", "experiment_summary.csv"))
  }

  best_params <- dplyr::bind_rows(
    training_results$best_params$random_forest %>% dplyr::mutate(model = "random_forest"),
    training_results$best_params$xgboost %>% dplyr::mutate(model = "xgboost")
  ) %>%
    dplyr::relocate(model)

  readr::write_csv(best_params, here::here("artifacts", "metrics", "best_hyperparameters.csv"))
  readr::write_csv(best_params, here::here("artifacts", "governance", "best_hyperparameters.csv"))

  invisible(list(experiments = experiments, best_params = best_params))
}

train_and_tune_models <- function(split_obj,
                                  house_recipe = NULL,
                                  mode = c("fast", "full"),
                                  seed = 2026,
                                  linear_recipe = NULL,
                                  tree_recipe = NULL,
                                  folds = NULL) {
  mode <- match.arg(mode)
  log_step(glue::glue("Training models in {mode} mode with resampling and model-specific recipes."))

  set.seed(seed)

  if (is.list(house_recipe) && all(c("linear_recipe", "tree_recipe") %in% names(house_recipe))) {
    linear_recipe <- house_recipe$linear_recipe
    tree_recipe <- house_recipe$tree_recipe
  }

  if (is.null(linear_recipe) && !is.null(house_recipe) && !is.list(house_recipe)) {
    linear_recipe <- house_recipe
  }

  if (is.null(tree_recipe) && !is.null(house_recipe) && !is.list(house_recipe)) {
    tree_recipe <- house_recipe
  }

  if (is.null(linear_recipe) || is.null(tree_recipe)) {
    stop(
      "Both linear_recipe and tree_recipe are required. ",
      "Use create_data_split_and_recipe() from R/04_split_recipe.R and pass ",
      "split_bundle$recipe, or pass linear_recipe and tree_recipe explicitly.",
      call. = FALSE
    )
  }

  train_data <- rsample::training(split_obj)

  if (is.null(folds)) {
    folds <- rsample::vfold_cv(
      train_data,
      v = ifelse(mode == "fast", 3, 5),
      strata = price_band
    )
  }

  regression_metrics <- yardstick::metric_set(yardstick::rmse, yardstick::mae, yardstick::rsq)

  linear_spec <- parsnip::linear_reg() %>%
    parsnip::set_engine("lm")

  rf_spec <- parsnip::rand_forest(
    trees = ifelse(mode == "fast", 150, 500),
    mtry = tune::tune(),
    min_n = tune::tune()
  ) %>%
    parsnip::set_engine("ranger", importance = "impurity") %>%
    parsnip::set_mode("regression")

  xgb_spec <- parsnip::boost_tree(
    trees = ifelse(mode == "fast", 150, 500),
    tree_depth = tune::tune(),
    learn_rate = tune::tune(),
    loss_reduction = tune::tune(),
    min_n = tune::tune(),
    mtry = tune::tune()
  ) %>%
    parsnip::set_engine("xgboost") %>%
    parsnip::set_mode("regression")

  linear_wf <- workflows::workflow() %>%
    workflows::add_recipe(linear_recipe) %>%
    workflows::add_model(linear_spec)

  rf_wf <- workflows::workflow() %>%
    workflows::add_recipe(tree_recipe) %>%
    workflows::add_model(rf_spec)

  xgb_wf <- workflows::workflow() %>%
    workflows::add_recipe(tree_recipe) %>%
    workflows::add_model(xgb_spec)

  model_registry <- tibble::tibble(
    model_id = c("linear_regression", "random_forest", "xgboost"),
    model_family = c("Linear model", "Tree ensemble", "Gradient boosted trees"),
    recipe_used = c("linear_recipe", "tree_recipe", "tree_recipe"),
    resampling_method = "vfold_cv",
    folds = length(unique(folds$id)),
    purpose = c(
      "Transparent baseline benchmark",
      "Non-linear tabular model for robust comparison",
      "Advanced high-performing model for market-value prediction"
    )
  )

  readr::write_csv(model_registry, here::here("artifacts", "metrics", "model_registry.csv"))

  control <- tune::control_grid(
    save_pred = TRUE,
    save_workflow = TRUE,
    verbose = FALSE,
    allow_par = TRUE
  )

  emit_training_progress("Fitting linear regression baseline.")
  linear_res <- tune::fit_resamples(
    linear_wf,
    resamples = folds,
    metrics = regression_metrics,
    control = tune::control_resamples(save_pred = TRUE, save_workflow = TRUE)
  )

  emit_training_progress("Tuning random forest.")
  rf_grid <- dials::grid_regular(
    dials::mtry(range = c(3, 12)),
    dials::min_n(range = c(5, 30)),
    levels = ifelse(mode == "fast", 3, 5)
  )

  rf_res <- tune::tune_grid(
    rf_wf,
    resamples = folds,
    grid = rf_grid,
    metrics = regression_metrics,
    control = control
  )

  emit_training_progress("Tuning XGBoost.")
  xgb_grid <- dials::grid_space_filling(
    dials::tree_depth(range = c(3, 8)),
    dials::learn_rate(range = c(-3, -1)),
    dials::loss_reduction(range = c(-5, 0)),
    dials::min_n(range = c(5, 30)),
    dials::mtry(range = c(3, 12)),
    size = ifelse(mode == "fast", 6, 15)
  )

  xgb_res <- tune::tune_grid(
    xgb_wf,
    resamples = folds,
    grid = xgb_grid,
    metrics = regression_metrics,
    control = control
  )

  fs::dir_create(here::here("artifacts", "models"))
  saveRDS(linear_res, here::here("artifacts", "models", "resamples_linear_regression.rds"))
  saveRDS(rf_res, here::here("artifacts", "models", "tuning_random_forest.rds"))
  saveRDS(xgb_res, here::here("artifacts", "models", "tuning_xgboost.rds"))

  emit_training_progress("Finalizing workflows and running last_fit on test data.")

  best_rf <- tune::select_best(rf_res, metric = "rmse")
  best_xgb <- tune::select_best(xgb_res, metric = "rmse")

  final_rf_wf <- tune::finalize_workflow(rf_wf, best_rf)
  final_xgb_wf <- tune::finalize_workflow(xgb_wf, best_xgb)

  linear_last <- tune::last_fit(linear_wf, split = split_obj, metrics = regression_metrics)
  rf_last <- tune::last_fit(final_rf_wf, split = split_obj, metrics = regression_metrics)
  xgb_last <- tune::last_fit(final_xgb_wf, split = split_obj, metrics = regression_metrics)

  results <- list(
    mode = mode,
    folds = folds,
    model_registry = model_registry,
    recipes = list(linear_recipe = linear_recipe, tree_recipe = tree_recipe),
    workflows = list(
      linear_regression = linear_wf,
      random_forest = final_rf_wf,
      xgboost = final_xgb_wf
    ),
    tuning = list(
      linear = linear_res,
      random_forest = rf_res,
      xgboost = xgb_res
    ),
    best_params = list(random_forest = best_rf, xgboost = best_xgb),
    last_fit = list(
      linear_regression = linear_last,
      random_forest = rf_last,
      xgboost = xgb_last
    )
  )

  saveRDS(results, here::here("artifacts", "models", "training_results.rds"))
  write_hyperparameter_artifacts(results)

  log_step("Model training, resampling, and hyperparameter experimentation completed.")
  results
}
