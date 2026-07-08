# Split, resampling, and model-specific recipes ----------------------

create_data_split_and_recipe <- function(data, seed = 2026, mode = c("fast", "full")) {
  mode <- match.arg(mode)
  log_step("Creating train/test split, resampling folds, and model-specific recipes.")

  set.seed(seed)

  split_obj <- rsample::initial_split(data, prop = 0.80, strata = price_band)
  train_data <- rsample::training(split_obj)

  fold_count <- ifelse(mode == "fast", 3, 5)
  folds <- rsample::vfold_cv(train_data, v = fold_count, strata = price_band)

  other_threshold <- ifelse(mode == "fast", 0.015, 0.005)

  # ---------------------------------------------------------------------------
  # Baseline recipe
  linear_recipe <- recipes::recipe(
    log_price ~ bedrooms + bathrooms + toilets + parking_space +
      title + state,
    data = train_data
  ) %>%
    recipes::step_novel(recipes::all_nominal_predictors()) %>%
    recipes::step_unknown(recipes::all_nominal_predictors()) %>%
    recipes::step_other(recipes::all_nominal_predictors(), threshold = other_threshold) %>%
    recipes::step_dummy(recipes::all_nominal_predictors()) %>%
    recipes::step_zv(recipes::all_predictors()) %>%
    recipes::step_lincomb(recipes::all_numeric_predictors()) %>%
    recipes::step_normalize(recipes::all_numeric_predictors())

  
  tree_recipe <- recipes::recipe(
    log_price ~ bedrooms + bathrooms + toilets + parking_space +
      title + town + state + market_hub + has_parking +
      total_rooms + total_wet_rooms + bathroom_bedroom_ratio +
      toilet_bedroom_ratio + parking_per_bedroom,
    data = train_data
  ) %>%
    recipes::step_novel(recipes::all_nominal_predictors()) %>%
    recipes::step_unknown(recipes::all_nominal_predictors()) %>%
    recipes::step_other(recipes::all_nominal_predictors(), threshold = other_threshold) %>%
    recipes::step_dummy(recipes::all_nominal_predictors()) %>%
    recipes::step_zv(recipes::all_predictors())

  fs::dir_create(here::here("artifacts", "models"))
  fs::dir_create(here::here("artifacts", "metrics"))
  fs::dir_create(here::here("artifacts", "governance"))

  saveRDS(split_obj, here::here("artifacts", "models", "data_split.rds"))
  saveRDS(folds, here::here("artifacts", "models", "resampling_folds.rds"))
  saveRDS(linear_recipe, here::here("artifacts", "models", "linear_recipe.rds"))
  saveRDS(tree_recipe, here::here("artifacts", "models", "tree_recipe.rds"))

  
  saveRDS(tree_recipe, here::here("artifacts", "models", "house_recipe.rds"))

  resampling_summary <- tibble::tibble(
    run_mode = mode,
    seed = seed,
    split_type = "initial_split",
    train_prop = 0.80,
    resampling_method = "vfold_cv",
    folds = fold_count,
    strata = "price_band",
    train_rows = nrow(rsample::training(split_obj)),
    test_rows = nrow(rsample::testing(split_obj)),
    created_at = as.character(Sys.time())
  )

  readr::write_csv(resampling_summary, here::here("artifacts", "metrics", "resampling_summary.csv"))
  readr::write_csv(resampling_summary, here::here("artifacts", "governance", "resampling_summary.csv"))

  list(
    split = split_obj,
    folds = folds,
    linear_recipe = linear_recipe,
    tree_recipe = tree_recipe,
    recipe = list(
      linear_recipe = linear_recipe,
      tree_recipe = tree_recipe
    )
  )
}
