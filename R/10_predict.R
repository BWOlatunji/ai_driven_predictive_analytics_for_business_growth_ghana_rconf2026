# Deployment-ready batch scoring -----------------------------------

validate_new_property_input <- function(data) {
  required <- c("bedrooms", "bathrooms", "toilets", "parking_space", "title", "town", "state")
  missing <- setdiff(required, names(janitor::clean_names(data)))

  if (length(missing) > 0) {
    stop(
      "New-property data is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

prepare_new_property_features <- function(data) {
  data %>%
    janitor::clean_names() %>%
    dplyr::mutate(
      bedrooms = as.numeric(bedrooms),
      bathrooms = as.numeric(bathrooms),
      toilets = as.numeric(toilets),
      parking_space = as.numeric(parking_space),
      title = as.factor(title),
      town = as.factor(town),
      state = as.factor(state),
      market_hub = dplyr::case_when(
        stringr::str_to_lower(as.character(state)) %in% c("lagos") ~ "lagos",
        stringr::str_to_lower(as.character(state)) %in% c("abuja", "fct", "federal capital territory") ~ "abuja_fct",
        stringr::str_to_lower(as.character(state)) %in% c("rivers") ~ "rivers",
        TRUE ~ "other_market"
      ) %>% as.factor(),

      
      has_parking = factor(parking_space > 0, levels = c(FALSE, TRUE)),

      total_rooms = bedrooms + bathrooms + toilets,
      total_wet_rooms = bathrooms + toilets,
      bathroom_bedroom_ratio = dplyr::if_else(bedrooms > 0, bathrooms / bedrooms, 0),
      toilet_bedroom_ratio = dplyr::if_else(bedrooms > 0, toilets / bedrooms, 0),
      parking_per_bedroom = dplyr::if_else(bedrooms > 0, parking_space / bedrooms, 0)
    )
}

capture_prediction_warnings <- function(expr, warning_path) {
  warnings_seen <- character()

  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  if (length(warnings_seen) > 0) {
    fs::dir_create(dirname(warning_path))
    writeLines(unique(warnings_seen), warning_path)

    if (exists("log_step", mode = "function")) {
      log_step(glue::glue("Scoring completed with input-governance warnings. See: {warning_path}"))
    } else {
      message("Scoring completed with input-governance warnings. See: ", warning_path)
    }
  }

  value
}

write_scoring_manifest <- function(input_path, model_path, output_path, row_count, warning_path) {
  fs::dir_create(here::here("artifacts", "governance"))

  manifest <- tibble::tibble(
    scored_at = as.character(Sys.time()),
    scoring_mode = "batch_scoring",
    input_path = input_path,
    model_path = model_path,
    output_path = output_path,
    rows_scored = row_count,
    target_scale = "log_price",
    business_output = "predicted_price_naira",
    warning_log = if (fs::file_exists(warning_path)) warning_path else NA_character_
  )

  readr::write_csv(manifest, here::here("artifacts", "governance", "scoring_manifest.csv"))
  readr::write_csv(manifest, here::here("artifacts", "metrics", "scoring_manifest.csv"))

  invisible(manifest)
}

score_new_properties <- function(input_path = here::here("data", "new", "sample_new_properties.csv"),
                                 model_path = here::here("artifacts", "model_package", "best_model.rds"),
                                 output_path = here::here("artifacts", "predictions", "scored_new_properties.csv")) {
  log_step("Scoring new property records with packaged model.")

  if (!fs::file_exists(input_path)) {
    stop("New-property input file not found: ", input_path, call. = FALSE)
  }

  if (!fs::file_exists(model_path)) {
    fallback_model <- here::here("artifacts", "models", "best_model.rds")
    if (fs::file_exists(fallback_model)) {
      model_path <- fallback_model
    } else {
      stop("Packaged model not found. Run scripts/04_package_model.R first.", call. = FALSE)
    }
  }

  model <- readRDS(model_path)
  new_data_raw <- readr::read_csv(input_path, show_col_types = FALSE)
  validate_new_property_input(new_data_raw)
  new_data <- prepare_new_property_features(new_data_raw)

  fs::dir_create(here::here("artifacts", "governance"))
  fs::dir_create(here::here("artifacts", "predictions"))
  fs::dir_create(here::here("artifacts", "metrics"))

  warning_path <- here::here("artifacts", "governance", "scoring_warnings.txt")
  if (fs::file_exists(warning_path)) fs::file_delete(warning_path)

  preds <- capture_prediction_warnings(
    predict(model, new_data) %>%
      dplyr::rename(predicted_log_price = .pred) %>%
      dplyr::mutate(predicted_price_naira = expm1(predicted_log_price)),
    warning_path = warning_path
  )

  scored <- dplyr::bind_cols(new_data_raw, preds)

  readr::write_csv(scored, output_path)
  write_scoring_manifest(input_path, model_path, output_path, nrow(scored), warning_path)

  log_step(glue::glue("Scored predictions written to: {output_path}"))
  scored
}
