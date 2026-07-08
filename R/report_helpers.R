# Report helper functions -----------------------------------------------
resolve_artifact_path <- function(path) {
  candidates <- unique(c(
    path,
    file.path(getwd(), path),
    file.path("..", path),
    file.path(getwd(), "..", path),
    if (requireNamespace("here", quietly = TRUE)) here::here(path) else character(0)
  ))

  existing <- candidates[file.exists(candidates)]

  if (length(existing) == 0L) {
    return(NA_character_)
  }

  normalizePath(existing[[1L]], winslash = "/", mustWork = TRUE)
}

safe_read_csv <- function(path) {
  resolved_path <- resolve_artifact_path(path)

  if (!is.na(resolved_path)) {
    return(readr::read_csv(resolved_path, show_col_types = FALSE))
  }

  tibble::tibble()
}

safe_include_graphic <- function(path, alt = "Workflow artifact") {
  resolved_path <- resolve_artifact_path(path)

  if (!is.na(resolved_path)) {
    image_src <- knitr::image_uri(resolved_path)
    html <- sprintf(
      '<div class="figure"><img src="%s" alt="%s" style="max-width:100%%; height:auto; display:block; margin: 1rem auto;"></div>',
      image_src,
      gsub('"', "&quot;", alt)
    )
    return(knitr::asis_output(html))
  }

  knitr::asis_output(sprintf(
    '<blockquote><p>Figure not available yet: <code>%s</code></p></blockquote>',
    path
  ))
}

fmt_naira <- function(x) {
  scales::label_number(prefix = "₦", big.mark = ",", accuracy = 1)(x)
}

fmt_pct <- function(x, accuracy = 0.1) {
  scales::percent(x, accuracy = accuracy)
}

empty_notice <- function(message) {
  knitr::asis_output(sprintf("> %s\n", message))
}

make_run_manifest_tbl <- function(run_manifest) {
  if (nrow(run_manifest) == 0L) {
    return(empty_notice("Run manifest was not found. Run the lifecycle script first."))
  }

  run_manifest |>
    dplyr::select(dplyr::any_of(c(
      "project_name", "use_case_name", "run_mode", "run_timestamp",
      "best_model", "best_rmse", "best_mae", "best_rsq", "r_version"
    ))) |>
    knitr::kable(caption = "Run manifest for reproducibility and governance")
}

make_model_comparison_tbl <- function(model_comparison) {
  if (nrow(model_comparison) == 0L) {
    return(empty_notice("Model comparison metrics were not found. Run the lifecycle script first."))
  }

  model_comparison |>
    dplyr::arrange(.data$rmse) |>
    dplyr::mutate(
      rmse = round(.data$rmse, 4),
      mae = round(.data$mae, 4),
      rsq = round(.data$rsq, 4)
    ) |>
    knitr::kable(caption = "Model ranking by RMSE on log-transformed price")
}

make_best_model_tbl <- function(best_model_metrics) {
  if (nrow(best_model_metrics) == 0L) {
    return(empty_notice("Best model metrics were not found. Run the lifecycle script first."))
  }

  best_model_metrics |>
    dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 4))) |>
    knitr::kable(caption = "Best model performance summary")
}

make_screening_candidates_tbl <- function(screening_candidates, n = 15L) {
  if (nrow(screening_candidates) == 0L) {
    return(empty_notice("Business screening candidates were not found. Run the lifecycle script first."))
  }

  screening_candidates |>
    dplyr::select(dplyr::any_of(c(
      "title", "town", "state", "bedrooms", "bathrooms", "toilets",
      "parking_space", "actual_price", "predicted_price", "price_gap",
      "price_gap_percent", "pricing_signal"
    ))) |>
    utils::head(n) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::any_of(c("actual_price", "predicted_price", "price_gap")),
        fmt_naira
      ),
      price_gap_percent = fmt_pct(.data$price_gap_percent)
    ) |>
    knitr::kable(caption = "Top business screening candidates for further investigation")
}

make_mlflow_tracking_tbl <- function(mlflow_ledger) {
  if (nrow(mlflow_ledger) == 0L) {
    return(empty_notice("MLflow tracking output was not found yet. Start the MLflow UI and run scripts/03_run_mlflow_tracking.R after model evaluation."))
  }

  mlflow_ledger |>
    dplyr::select(dplyr::any_of(c(
      "logged_at", "tracking_mode", "tracking_uri", "best_model",
      "best_rmse", "best_mae", "best_rsq", "models_compared", "reason"
    ))) |>
    dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 4))) |>
    knitr::kable(caption = "MLflow tracking or fallback ledger summary")
}

load_report_artifacts <- function() {
  list(
    model_comparison = safe_read_csv("artifacts/metrics/model_comparison.csv"),
    best_model_metrics = safe_read_csv("artifacts/metrics/best_model_metrics.csv"),
    run_manifest = safe_read_csv("artifacts/metrics/run_manifest.csv"),
    resampling_summary = safe_read_csv("artifacts/metrics/resampling_summary.csv"),
    validation_summary = safe_read_csv("artifacts/metrics/validation_summary.csv"),
    location_market_summary = safe_read_csv("artifacts/metrics/location_market_summary.csv"),
    screening_candidates = safe_read_csv("artifacts/predictions/business_screening_candidates.csv"),
    mlflow_ledger = safe_read_csv("artifacts/metrics/mlflow_experiment_ledger.csv")
  )
}
