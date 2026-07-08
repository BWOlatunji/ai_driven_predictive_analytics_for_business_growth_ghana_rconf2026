# Evaluation, ranking, business signals -----------------------------

collect_model_metrics <- function(training_results) {
  log_step("Collecting and ranking model metrics.")
  
  comparison <- purrr::imap_dfr(
    training_results$last_fit,
    ~ tune::collect_metrics(.x) %>%
      dplyr::mutate(model = .y)
  ) %>%
    dplyr::select(model, .metric, .estimate, .estimator) %>%
    tidyr::pivot_wider(names_from = .metric, values_from = .estimate) %>%
    dplyr::arrange(rmse) %>%
    dplyr::mutate(rank = dplyr::row_number()) %>%
    dplyr::select(rank, model, rmse, mae, rsq, .estimator)
  
  readr::write_csv(
    comparison,
    here::here("artifacts", "metrics", "model_comparison.csv")
  )
  
  best_model_name <- comparison$model[[1]]
  best_summary <- comparison %>% dplyr::slice(1)
  
  readr::write_csv(
    best_summary,
    here::here("artifacts", "metrics", "best_model_metrics.csv")
  )
  readr::write_csv(
    best_summary,
    here::here("artifacts", "metrics", "best_model_summary.csv")
  )
  
  log_step(glue::glue("Best model selected: {best_model_name}"))
  
  list(
    comparison = comparison,
    best_model_name = best_model_name,
    best_summary = best_summary
  )
}


create_feature_importance_plot <- function(best_workflow, best_model_name) {
  fitted_parsnip <- workflows::extract_fit_parsnip(best_workflow)
  
  if (identical(best_model_name, "random_forest")) {
    importance <- fitted_parsnip$fit$variable.importance
    
    if (is.null(importance) || length(importance) == 0L) {
      return(NULL)
    }
    
    importance_df <- tibble::tibble(
      feature = names(importance),
      importance = as.numeric(importance)
    ) %>%
      dplyr::arrange(dplyr::desc(.data$importance)) %>%
      dplyr::slice_head(n = 20)
    
    return(
      ggplot2::ggplot(
        importance_df,
        ggplot2::aes(
          x = stats::reorder(.data$feature, .data$importance),
          y = .data$importance
        )
      ) +
        ggplot2::geom_col() +
        ggplot2::coord_flip() +
        ggplot2::labs(
          title = glue::glue("Feature Importance: {best_model_name}"),
          subtitle = "Native random forest impurity-based importance",
          x = NULL,
          y = "Importance"
        )
    )
  }
  
  if (identical(best_model_name, "xgboost")) {
    importance_df <- xgboost::xgb.importance(model = fitted_parsnip$fit)
    
    if (is.null(importance_df) || nrow(importance_df) == 0L) {
      return(NULL)
    }
    
    importance_df <- importance_df %>%
      tibble::as_tibble() %>%
      dplyr::slice_head(n = 20)
    
    return(
      ggplot2::ggplot(
        importance_df,
        ggplot2::aes(
          x = stats::reorder(.data$Feature, .data$Gain),
          y = .data$Gain
        )
      ) +
        ggplot2::geom_col() +
        ggplot2::coord_flip() +
        ggplot2::labs(
          title = glue::glue("Feature Importance: {best_model_name}"),
          subtitle = "Native XGBoost gain-based importance",
          x = NULL,
          y = "Gain"
        )
    )
  }
  
  NULL
}

create_evaluation_artifacts <- function(training_results, split_obj, ranking_results) {
  log_step("Creating evaluation plots and business decision-support outputs.")
  
  best_name <- ranking_results$best_model_name
  best_last_fit <- training_results$last_fit[[best_name]]
  best_workflow <- best_last_fit$.workflow[[1]]
  
  saveRDS(best_workflow, here::here("artifacts", "models", "best_model_workflow.rds"))
  saveRDS(best_workflow, here::here("artifacts", "models", "best_model.rds"))
  
  test_data <- rsample::testing(split_obj) %>%
    dplyr::mutate(.row = dplyr::row_number())
  
  predictions <- tune::collect_predictions(best_last_fit) %>%
    dplyr::mutate(
      predicted_price = expm1(.pred),
      actual_price = expm1(log_price),
      price_gap = actual_price - predicted_price,
      price_gap_percent = price_gap / pmax(predicted_price, 1),
      pricing_signal = dplyr::case_when(
        price_gap_percent <= -0.80 ~ "Data quality review: unusually below model estimate",
        price_gap_percent > -0.80 & price_gap_percent <= -0.20 ~ "Potential opportunity: below model estimate",
        price_gap_percent > -0.20 & price_gap_percent < 0.20 ~ "Close to model estimate",
        price_gap_percent >= 0.20 ~ "Potentially above model estimate",
        TRUE ~ "Review required"
      )
    )
  
  predictions_enriched <- predictions %>%
    dplyr::bind_cols(
      test_data %>%
        dplyr::select(
          title, town, state, bedrooms, bathrooms, toilets,
          parking_space, price_raw, market_hub
        )
    )
  
  readr::write_csv(
    predictions_enriched,
    here::here("artifacts", "predictions", "test_predictions_with_business_signals.csv")
  )
  readr::write_csv(
    predictions_enriched,
    here::here("artifacts", "predictions", "test_predictions.csv")
  )
  
  business_screening_candidates <- predictions_enriched %>%
    dplyr::filter(
      pricing_signal == "Potential opportunity: below model estimate"
    ) %>%
    dplyr::arrange(price_gap_percent) %>%
    dplyr::select(
      title, town, state,
      bedrooms, bathrooms, toilets, parking_space,
      actual_price, predicted_price,
      price_gap, price_gap_percent,
      pricing_signal
    ) %>%
    dplyr::slice_head(n = 25)
  
  data_quality_review_candidates <- predictions_enriched %>%
    dplyr::filter(
      pricing_signal == "Data quality review: unusually below model estimate"
    ) %>%
    dplyr::arrange(price_gap_percent) %>%
    dplyr::select(
      title, town, state,
      bedrooms, bathrooms, toilets, parking_space,
      actual_price, predicted_price,
      price_gap, price_gap_percent,
      pricing_signal
    ) %>%
    dplyr::slice_head(n = 25)
  
  readr::write_csv(
    business_screening_candidates,
    here::here("artifacts", "predictions", "business_screening_candidates.csv")
  )
  readr::write_csv(
    business_screening_candidates,
    here::here("artifacts", "metrics", "top_screening_candidates.csv")
  )
  readr::write_csv(
    data_quality_review_candidates,
    here::here("artifacts", "predictions", "data_quality_review_candidates.csv")
  )
  
  location_market_summary <- predictions_enriched %>%
    dplyr::group_by(state, town) %>%
    dplyr::summarise(
      listings = dplyr::n(),
      median_actual_price = median(actual_price, na.rm = TRUE),
      median_predicted_price = median(predicted_price, na.rm = TRUE),
      median_price_gap_percent = median(price_gap_percent, na.rm = TRUE),
      data_quality_review_count = sum(
        pricing_signal == "Data quality review: unusually below model estimate",
        na.rm = TRUE
      ),
      potential_opportunity_count = sum(
        pricing_signal == "Potential opportunity: below model estimate",
        na.rm = TRUE
      ),
      close_to_estimate_count = sum(
        pricing_signal == "Close to model estimate",
        na.rm = TRUE
      ),
      above_estimate_count = sum(
        pricing_signal == "Potentially above model estimate",
        na.rm = TRUE
      ),
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(listings), median_price_gap_percent)
  
  readr::write_csv(
    location_market_summary,
    here::here("artifacts", "metrics", "location_market_summary.csv")
  )
  
  comparison_plot <- ranking_results$comparison %>%
    ggplot2::ggplot(ggplot2::aes(x = reorder(model, rmse), y = rmse)) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Model Comparison by RMSE",
      subtitle = "Lower RMSE indicates stronger predictive performance on log-price",
      x = "Model",
      y = "RMSE"
    )
  
  save_plot_artifact(comparison_plot, here::here("artifacts", "figures", "model_comparison_rmse.png"))
  
  actual_predicted_plot <- predictions_enriched %>%
    ggplot2::ggplot(ggplot2::aes(x = actual_price, y = predicted_price)) +
    ggplot2::geom_point(alpha = 0.35) +
    ggplot2::geom_abline(linetype = "dashed") +
    ggplot2::scale_x_log10(labels = scales::label_number(scale_cut = scales::cut_short_scale())) +
    ggplot2::scale_y_log10(labels = scales::label_number(scale_cut = scales::cut_short_scale())) +
    ggplot2::labs(
      title = "Actual vs Predicted Property Prices",
      subtitle = glue::glue("Best model: {best_name}"),
      x = "Actual price",
      y = "Predicted price"
    )
  
  save_plot_artifact(actual_predicted_plot, here::here("artifacts", "figures", "predicted_vs_actual.png"))
  
  gap_plot <- predictions_enriched %>%
    ggplot2::ggplot(ggplot2::aes(x = price_gap_percent)) +
    ggplot2::geom_histogram(bins = 50) +
    ggplot2::scale_x_continuous(labels = scales::label_percent()) +
    ggplot2::labs(
      title = "Distribution of Pricing Gap",
      subtitle = "Negative values indicate listings below the model estimate",
      x = "Actual price minus predicted price, as % of predicted price",
      y = "Number of listings"
    )
  
  save_plot_artifact(gap_plot, here::here("artifacts", "figures", "price_gap_distribution.png"))
  
  
  feature_importance_path <- here::here("artifacts", "figures", "feature_importance.png")
  if (fs::file_exists(feature_importance_path)) {
    fs::file_delete(feature_importance_path)
  }
  
  importance_plot <- tryCatch(
    create_feature_importance_plot(
      best_workflow = best_workflow,
      best_model_name = best_name
    ),
    error = function(e) {
      log_step(glue::glue("Feature importance plot skipped: {conditionMessage(e)}"))
      NULL
    }
  )
  
  if (!is.null(importance_plot)) {
    save_plot_artifact(importance_plot, feature_importance_path)
  } else {
    log_step(glue::glue("Feature importance plot skipped for selected model: {best_name}"))
  }
  
  list(
    best_workflow = best_workflow,
    predictions = predictions_enriched,
    location_market_summary = location_market_summary,
    business_screening_candidates = business_screening_candidates,
    data_quality_review_candidates = data_quality_review_candidates,
    top_screening_candidates = business_screening_candidates
  )
}
