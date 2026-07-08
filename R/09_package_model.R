# Model packaging and governance ------------------------------------

copy_if_exists <- function(from, to) {
  if (fs::file_exists(from)) {
    fs::file_copy(from, to, overwrite = TRUE)
    TRUE
  } else {
    FALSE
  }
}

write_model_card <- function(package_dir, metadata) {
  model_card <- c(
    "# Model Card: Nigerian Real Estate Market Intelligence",
    "",
    "## Intended use",
    "This model is a decision-support tool for estimating Nigerian property listing values and screening potential pricing gaps for further business investigation.",
    "",
    "## Not intended for",
    "The model should not be used as the sole basis for investment, lending, legal, valuation, or purchase decisions. It does not replace legal due diligence, physical inspection, title verification, or expert market judgment.",
    "",
    "## Target",
    "The model predicts `log_price`, which is transformed back to estimated naira price for stakeholder interpretation.",
    "",
    "## Champion model",
    paste0("Best model: ", metadata$best_model),
    paste0("RMSE: ", metadata$best_rmse),
    paste0("MAE: ", metadata$best_mae),
    paste0("R-squared: ", metadata$best_rsq),
    "",
    "## Key limitations",
    "The dataset does not include property size, exact address, building age, distance to commercial centers, title quality, road quality, neighborhood security, rental yield, or macroeconomic conditions.",
    "",
    "## Monitoring recommendation",
    "Track prediction error over time, monitor large price-gap outliers, refresh the model when new market data becomes available, and review feature drift by state, town, and property type."
  )

  writeLines(model_card, file.path(package_dir, "model_card.md"))
}

create_feature_contract <- function(package_dir) {
  contract <- tibble::tibble(
    feature = c(
      "bedrooms", "bathrooms", "toilets", "parking_space", "title", "town", "state",
      "market_hub", "has_parking", "total_rooms", "total_wet_rooms",
      "bathroom_bedroom_ratio", "toilet_bedroom_ratio", "parking_per_bedroom"
    ),
    type = c(
      "numeric", "numeric", "numeric", "numeric", "categorical", "categorical", "categorical",
      "categorical", "logical/integer", "numeric", "numeric", "numeric", "numeric", "numeric"
    ),
    required_for = c(
      rep("all_models", 4), rep("all_models", 3),
      "tree_models", "tree_models", "tree_models", "tree_models", "tree_models", "tree_models", "tree_models"
    ),
    description = c(
      "Number of bedrooms", "Number of bathrooms", "Number of toilets", "Number of parking spaces",
      "Property type/title", "Town where property is located", "State where property is located",
      "Market hub grouping derived from location", "Whether the property has parking",
      "Bedrooms + bathrooms + toilets", "Bathrooms + toilets", "Bathrooms divided by bedrooms",
      "Toilets divided by bedrooms", "Parking spaces divided by bedrooms"
    )
  )

  readr::write_csv(contract, file.path(package_dir, "feature_contract.csv"))
  readr::write_csv(contract, here::here("artifacts", "governance", "feature_contract.csv"))
  contract
}

package_best_model <- function(package_dir = here::here("artifacts", "model_package")) {
  log_step("Packaging champion model and governance artifacts.")

  fs::dir_create(package_dir)
  fs::dir_create(here::here("artifacts", "governance"))

  manifest_path <- here::here("artifacts", "metrics", "run_manifest.csv")
  best_metrics_path <- here::here("artifacts", "metrics", "best_model_metrics.csv")
  model_path <- here::here("artifacts", "models", "best_model.rds")

  manifest <- if (fs::file_exists(manifest_path)) {
    readr::read_csv(manifest_path, show_col_types = FALSE)
  } else {
    tibble::tibble(best_model = NA_character_, best_rmse = NA_real_, best_mae = NA_real_, best_rsq = NA_real_)
  }

  metadata <- list(
    package_version = "v2-production-aware",
    packaged_at = as.character(Sys.time()),
    use_case = "Nigeria real estate market intelligence",
    target = "log_price",
    prediction_output = "predicted_price_naira",
    best_model = if (nrow(manifest) > 0) manifest$best_model[[1]] else NA_character_,
    best_rmse = if (nrow(manifest) > 0) manifest$best_rmse[[1]] else NA_real_,
    best_mae = if (nrow(manifest) > 0) manifest$best_mae[[1]] else NA_real_,
    best_rsq = if (nrow(manifest) > 0) manifest$best_rsq[[1]] else NA_real_,
    model_file = "best_model.rds",
    feature_contract = "feature_contract.csv",
    model_card = "model_card.md"
  )

  copy_if_exists(model_path, file.path(package_dir, "best_model.rds"))
  copy_if_exists(best_metrics_path, file.path(package_dir, "training_metrics.csv"))
  copy_if_exists(manifest_path, file.path(package_dir, "run_manifest.csv"))
  copy_if_exists(here::here("artifacts", "metrics", "best_hyperparameters.csv"), file.path(package_dir, "best_hyperparameters.csv"))
  copy_if_exists(here::here("artifacts", "metrics", "resampling_summary.csv"), file.path(package_dir, "resampling_summary.csv"))

  create_feature_contract(package_dir)
  write_model_card(package_dir, metadata)

  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(metadata, file.path(package_dir, "model_metadata.json"), auto_unbox = TRUE, pretty = TRUE)
    jsonlite::write_json(metadata, here::here("artifacts", "governance", "model_metadata.json"), auto_unbox = TRUE, pretty = TRUE)
  }

  deployment_notes <- c(
    "# Deployment Notes",
    "",
    "This package supports batch scoring through `scripts/05_score_new_data.R`.",
    "For live serving, wrap `score_new_properties()` in a plumber or vetiver endpoint.",
    "Before production use, add authentication, monitoring, data quality checks, versioned model registry, and rollback procedures."
  )
  writeLines(deployment_notes, file.path(package_dir, "deployment_notes.md"))
  writeLines(deployment_notes, here::here("artifacts", "governance", "deployment_notes.md"))

  log_step(glue::glue("Model package written to: {package_dir}"))
  invisible(metadata)
}
