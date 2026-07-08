# Mlflow tracking

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

mlflow_tracking_uri <- function() {
  uri <- Sys.getenv("MLFLOW_TRACKING_URI", unset = "")
  if (!nzchar(uri)) {
    uri <- "http://127.0.0.1:5001"
  }
  sub("/+$", "", uri)
}

mlflow_endpoint <- function(path, tracking_uri = mlflow_tracking_uri()) {
  paste0(tracking_uri, path)
}

mlflow_now_ms <- function() {
  floor(as.numeric(Sys.time()) * 1000)
}

mlflow_rest_post <- function(path, body = list(), tracking_uri = mlflow_tracking_uri()) {
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("Package 'httr' is required for MLflow REST logging.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for MLflow REST logging.", call. = FALSE)
  }

  response <- httr::POST(
    url = mlflow_endpoint(path, tracking_uri),
    body = jsonlite::toJSON(body, auto_unbox = TRUE, null = "null", digits = NA),
    encode = "json",
    httr::content_type_json()
  )

  status <- httr::status_code(response)
  text <- httr::content(response, as = "text", encoding = "UTF-8")

  if (status >= 300) {
    stop(
      paste0(
        "MLflow REST call failed: ", path,
        " returned HTTP ", status,
        "\n", text
      ),
      call. = FALSE
    )
  }

  parsed <- if (nzchar(text)) {
    tryCatch(
      jsonlite::fromJSON(text, simplifyVector = FALSE),
      error = function(e) list(parse_error = conditionMessage(e))
    )
  } else {
    list()
  }

  parsed$.raw_text <- text
  parsed$.status_code <- status
  parsed
}

mlflow_clean_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  x <- x[[1]]
  if (is.null(x) || is.na(x)) return(NA_character_)
  as.character(x)
}

extract_mlflow_run_id <- function(parsed_response) {
  nested_candidates <- c(
    mlflow_clean_scalar(parsed_response$run$info$run_id),
    mlflow_clean_scalar(parsed_response$run$info$run_uuid),
    mlflow_clean_scalar(parsed_response$info$run_id),
    mlflow_clean_scalar(parsed_response$info$run_uuid),
    mlflow_clean_scalar(parsed_response$run_id),
    mlflow_clean_scalar(parsed_response$run_uuid)
  )

  nested_candidates <- nested_candidates[!is.na(nested_candidates) & nzchar(nested_candidates)]
  if (length(nested_candidates) > 0) {
    return(nested_candidates[[1]])
  }

  
  flat <- tryCatch(
    unlist(parsed_response, recursive = TRUE, use.names = TRUE),
    error = function(e) character()
  )

  if (length(flat) > 0) {
    nm <- names(flat)
    idx <- which(grepl("(^|\\.)run_id$", nm) | grepl("(^|\\.)run_uuid$", nm))
    if (length(idx) > 0) {
      vals <- as.character(flat[idx])
      vals <- vals[!is.na(vals) & nzchar(vals)]
      if (length(vals) > 0) return(vals[[1]])
    }
  }

  raw_text <- parsed_response$.raw_text %||% parsed_response$raw_text %||% ""
  if (nzchar(raw_text)) {
    m <- regexec('"run_id"\\s*:\\s*"([^"]+)"', raw_text, perl = TRUE)
    hit <- regmatches(raw_text, m)[[1]]
    if (length(hit) >= 2 && nzchar(hit[[2]])) return(hit[[2]])

    m <- regexec('"run_uuid"\\s*:\\s*"([^"]+)"', raw_text, perl = TRUE)
    hit <- regmatches(raw_text, m)[[1]]
    if (length(hit) >= 2 && nzchar(hit[[2]])) return(hit[[2]])
  }

  NA_character_
}

extract_mlflow_experiment_id <- function(parsed_response) {
  experiment_id <- mlflow_clean_scalar(parsed_response$experiment_id)
  if (!is.na(experiment_id) && nzchar(experiment_id)) return(experiment_id)

  flat <- tryCatch(
    unlist(parsed_response, recursive = TRUE, use.names = TRUE),
    error = function(e) character()
  )
  if (length(flat) > 0) {
    idx <- which(grepl("(^|\\.)experiment_id$", names(flat)))
    if (length(idx) > 0) {
      vals <- as.character(flat[idx])
      vals <- vals[!is.na(vals) & nzchar(vals)]
      if (length(vals) > 0) return(vals[[1]])
    }
  }

  raw_text <- parsed_response$.raw_text %||% parsed_response$raw_text %||% ""
  if (nzchar(raw_text)) {
    m <- regexec('"experiment_id"\\s*:\\s*"?([^",}]+)"?', raw_text, perl = TRUE)
    hit <- regmatches(raw_text, m)[[1]]
    if (length(hit) >= 2 && nzchar(hit[[2]])) return(hit[[2]])
  }

  NA_character_
}

get_or_create_mlflow_experiment <- function(experiment_name, tracking_uri = mlflow_tracking_uri()) {
  search_response <- mlflow_rest_post(
    "/api/2.0/mlflow/experiments/search",
    body = list(max_results = 1000),
    tracking_uri = tracking_uri
  )

  experiments <- search_response$experiments
  if (!is.null(experiments) && length(experiments) > 0) {
    for (exp in experiments) {
      if (identical(exp$name, experiment_name)) {
        return(as.character(exp$experiment_id))
      }
    }
  }

  create_response <- mlflow_rest_post(
    "/api/2.0/mlflow/experiments/create",
    body = list(name = experiment_name),
    tracking_uri = tracking_uri
  )

  experiment_id <- extract_mlflow_experiment_id(create_response)
  if (is.na(experiment_id) || !nzchar(experiment_id)) {
    stop(
      paste0(
        "MLflow experiment was created, but no experiment_id could be parsed. Response: ",
        create_response$.raw_text %||% "<no raw response>"
      ),
      call. = FALSE
    )
  }

  experiment_id
}

mlflow_safe_param <- function(key, value) {
  value <- value %||% ""
  value <- as.character(value[[1]])
  if (is.na(value) || !nzchar(value)) value <- "NA"
  list(key = as.character(key), value = value)
}

mlflow_safe_metric <- function(key, value, timestamp, step = 0) {
  value <- suppressWarnings(as.numeric(value[[1]]))
  if (is.na(value) || !is.finite(value)) return(NULL)
  list(
    key = as.character(key),
    value = value,
    timestamp = timestamp,
    step = as.integer(step)
  )
}

mlflow_compact_list <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}


write_mlflow_experiment_ledger <- function(tracking_mode,
                                           run_id = NA_character_,
                                           run_name = NA_character_,
                                           experiment_name = NA_character_,
                                           reason = NA_character_) {
  fs::dir_create(here::here("artifacts", "metrics"))
  fs::dir_create(here::here("artifacts", "governance"))

  model_comparison_path <- here::here("artifacts", "metrics", "model_comparison.csv")
  best_metrics_path <- here::here("artifacts", "metrics", "best_model_metrics.csv")
  ledger_path <- here::here("artifacts", "metrics", "mlflow_experiment_ledger.csv")

  model_comparison <- if (fs::file_exists(model_comparison_path)) {
    readr::read_csv(model_comparison_path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  best_metrics <- if (fs::file_exists(best_metrics_path)) {
    readr::read_csv(best_metrics_path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  ledger <- tibble::tibble(
    logged_at = as.character(Sys.time()),
    tracking_mode = tracking_mode,
    experiment_name = experiment_name,
    run_name = run_name,
    run_id = run_id,
    tracking_uri = mlflow_tracking_uri(),
    best_model = if ("model" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$model[[1]] else NA_character_,
    best_rmse = if ("rmse" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$rmse[[1]] else NA_real_,
    best_mae = if ("mae" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$mae[[1]] else NA_real_,
    best_rsq = if ("rsq" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$rsq[[1]] else NA_real_,
    models_compared = if (nrow(model_comparison) > 0 && "model" %in% names(model_comparison)) paste(model_comparison$model, collapse = ", ") else NA_character_,
    model_comparison_path = model_comparison_path,
    best_metrics_path = best_metrics_path,
    reason = reason
  )

  readr::write_csv(ledger, ledger_path)
  readr::write_csv(ledger, here::here("artifacts", "governance", "mlflow_experiment_ledger.csv"))
  ledger_path
}

write_mlflow_fallback_ledger <- function(reason = NULL) {
  fs::dir_create(here::here("artifacts", "metrics"))
  fs::dir_create(here::here("artifacts", "governance"))

  model_comparison_path <- here::here("artifacts", "metrics", "model_comparison.csv")
  best_metrics_path <- here::here("artifacts", "metrics", "best_model_metrics.csv")
  fallback_path <- here::here("artifacts", "metrics", "mlflow_fallback_experiment_ledger.csv")

  model_comparison <- if (fs::file_exists(model_comparison_path)) {
    readr::read_csv(model_comparison_path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  best_metrics <- if (fs::file_exists(best_metrics_path)) {
    readr::read_csv(best_metrics_path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  ledger <- tibble::tibble(
    logged_at = as.character(Sys.time()),
    tracking_mode = "local_fallback_ledger",
    reason = reason %||% "MLflow was unavailable or REST logging failed.",
    tracking_uri = mlflow_tracking_uri(),
    model_comparison_path = model_comparison_path,
    best_metrics_path = best_metrics_path,
    best_model = if ("model" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$model[[1]] else NA_character_,
    best_rmse = if ("rmse" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$rmse[[1]] else NA_real_,
    best_mae = if ("mae" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$mae[[1]] else NA_real_,
    best_rsq = if ("rsq" %in% names(best_metrics) && nrow(best_metrics) > 0) best_metrics$rsq[[1]] else NA_real_,
    models_compared = if (nrow(model_comparison) > 0 && "model" %in% names(model_comparison)) paste(model_comparison$model, collapse = ", ") else NA_character_
  )

  readr::write_csv(ledger, fallback_path)
  write_mlflow_experiment_ledger(
    tracking_mode = "local_fallback_ledger",
    experiment_name = "ghana-r-2026-real-estate-market-intelligence",
    reason = reason %||% "MLflow was unavailable or REST logging failed."
  )
  fallback_path
}

log_metrics_params_to_mlflow <- function(experiment_name = "ghana-r-2026-real-estate-market-intelligence") {
  tracking_uri <- mlflow_tracking_uri()
  run_name <- paste0("v2-production-aware-", format(Sys.time(), "%Y%m%d-%H%M%S"))
  diagnostic_file <- here::here("artifacts", "governance", "mlflow_tracking_diagnostic.txt")
  fs::dir_create(dirname(diagnostic_file))

  model_comparison_path <- here::here("artifacts", "metrics", "model_comparison.csv")
  best_metrics_path <- here::here("artifacts", "metrics", "best_model_metrics.csv")
  run_manifest_path <- here::here("artifacts", "metrics", "run_manifest.csv")

  model_comparison <- if (fs::file_exists(model_comparison_path)) {
    readr::read_csv(model_comparison_path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  best_metrics <- if (fs::file_exists(best_metrics_path)) {
    readr::read_csv(best_metrics_path, show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  tryCatch({
    experiment_id <- get_or_create_mlflow_experiment(experiment_name, tracking_uri)

    create_run_response <- mlflow_rest_post(
      "/api/2.0/mlflow/runs/create",
      body = list(
        experiment_id = experiment_id,
        start_time = mlflow_now_ms(),
        run_name = run_name,
        tags = list(
          list(key = "mlflow.runName", value = run_name),
          list(key = "project", value = "ghana-r-2026-ai-predictive-analytics-r"),
          list(key = "workflow_stage", value = "production-aware-workshop-v2"),
          list(key = "tracking_client", value = "R REST API")
        )
      ),
      tracking_uri = tracking_uri
    )

    run_id <- extract_mlflow_run_id(create_run_response)

    if (is.na(run_id) || !nzchar(run_id)) {
      stop(
        paste0(
          "MLflow run was created, but no run_id could be parsed from the response: ",
          create_run_response$.raw_text %||% "<no raw response>"
        ),
        call. = FALSE
      )
    }

    timestamp <- mlflow_now_ms()

    params <- list(
      mlflow_safe_param("use_case", "Nigeria real estate market intelligence"),
      mlflow_safe_param("target", "log_price"),
      mlflow_safe_param("resampling", "v-fold cross validation plus holdout test"),
      mlflow_safe_param(
        "models_compared",
        if (nrow(model_comparison) > 0 && "model" %in% names(model_comparison)) paste(model_comparison$model, collapse = ", ") else "unknown"
      ),
      mlflow_safe_param("model_comparison_csv", model_comparison_path),
      mlflow_safe_param("best_metrics_csv", best_metrics_path),
      mlflow_safe_param("run_manifest_csv", run_manifest_path)
    )

    metrics <- list()

    if (nrow(best_metrics) > 0) {
      if ("rmse" %in% names(best_metrics)) metrics <- c(metrics, list(mlflow_safe_metric("champion_rmse", best_metrics$rmse[[1]], timestamp, 0)))
      if ("mae" %in% names(best_metrics)) metrics <- c(metrics, list(mlflow_safe_metric("champion_mae", best_metrics$mae[[1]], timestamp, 0)))
      if ("rsq" %in% names(best_metrics)) metrics <- c(metrics, list(mlflow_safe_metric("champion_rsq", best_metrics$rsq[[1]], timestamp, 0)))
      if ("model" %in% names(best_metrics)) params <- c(params, list(mlflow_safe_param("champion_model", best_metrics$model[[1]])))
    }

    if (nrow(model_comparison) > 0 && all(c("model", "rmse", "mae", "rsq") %in% names(model_comparison))) {
      for (i in seq_len(nrow(model_comparison))) {
        safe_model_name <- gsub("[^A-Za-z0-9_]", "_", model_comparison$model[[i]])
        metrics <- c(
          metrics,
          list(
            mlflow_safe_metric(paste0(safe_model_name, "_rmse"), model_comparison$rmse[[i]], timestamp, i),
            mlflow_safe_metric(paste0(safe_model_name, "_mae"), model_comparison$mae[[i]], timestamp, i),
            mlflow_safe_metric(paste0(safe_model_name, "_rsq"), model_comparison$rsq[[i]], timestamp, i)
          )
        )
      }
    }

    metrics <- mlflow_compact_list(metrics)
    params <- mlflow_compact_list(params)

    mlflow_rest_post(
      "/api/2.0/mlflow/runs/log-batch",
      body = list(
        run_id = run_id,
        metrics = metrics,
        params = params,
        tags = list(
          list(key = "mlflow.runName", value = run_name),
          list(key = "status", value = "logged_from_r_rest_api"),
          list(key = "artifact_location", value = here::here("artifacts"))
        )
      ),
      tracking_uri = tracking_uri
    )

    mlflow_rest_post(
      "/api/2.0/mlflow/runs/update",
      body = list(
        run_id = run_id,
        status = "FINISHED",
        end_time = mlflow_now_ms()
      ),
      tracking_uri = tracking_uri
    )

    if (fs::file_exists(diagnostic_file)) {
      fs::file_delete(diagnostic_file)
    }

    write_mlflow_experiment_ledger(
      tracking_mode = "mlflow_rest_api_success",
      run_id = run_id,
      run_name = run_name,
      experiment_name = experiment_name,
      reason = "Logged successfully to MLflow."
    )

    msg <- paste0(
      "MLflow run logged successfully: ", run_name,
      "\nMLflow run ID: ", run_id,
      "\nOpen MLflow UI at: ", tracking_uri
    )
    if (exists("log_step")) log_step(msg) else message(msg)

    invisible(list(run_id = run_id, run_name = run_name, tracking_uri = tracking_uri))
  }, error = function(e) {
    diagnostic <- c(
      "MLflow REST logging failed.",
      "",
      paste0("Tracking URI: ", tracking_uri),
      paste0("Experiment: ", experiment_name),
      paste0("Run name: ", run_name),
      "",
      "Error message:",
      conditionMessage(e),
      "",
      "The workflow wrote the local fallback ledger instead."
    )
    writeLines(diagnostic, diagnostic_file)

    fallback_path <- write_mlflow_fallback_ledger(conditionMessage(e))
    if (exists("log_step")) {
      log_step(glue::glue("MLflow unavailable; wrote local experiment ledger: {fallback_path}"))
    } else {
      message("MLflow unavailable; wrote local experiment ledger: ", fallback_path)
    }
    invisible(FALSE)
  })
}
