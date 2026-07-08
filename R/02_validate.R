# Data preparation and validation -----------------------------------

validate_housing_data <- function(data, report_path = here::here("artifacts", "reports", "validation_report.html")) {
  log_step("Running data validation checks")

  required_columns <- c(
    "bedrooms", "bathrooms", "toilets", "parking_space",
    "title", "town", "state", "price"
  )

  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  validation_agent <-
    pointblank::create_agent(tbl = data, label = "Nigeria housing data validation") %>%
    pointblank::col_exists(columns = all_of(required_columns)) %>%
    pointblank::col_vals_not_null(columns = all_of(required_columns)) %>%
    pointblank::col_vals_gt(columns = price, value = 0) %>%
    pointblank::col_vals_between(columns = bedrooms, left = 0, right = 30) %>%
    pointblank::col_vals_between(columns = bathrooms, left = 0, right = 30) %>%
    pointblank::col_vals_between(columns = toilets, left = 0, right = 30) %>%
    pointblank::col_vals_between(columns = parking_space, left = 0, right = 50) %>%
    pointblank::interrogate()

  pointblank::export_report(validation_agent, filename = report_path)

  validation_summary <- tibble::tibble(
    validation_report = report_path,
    rows = nrow(data),
    columns = ncol(data),
    duplicate_rows = sum(duplicated(data)),
    min_price = min(data$price, na.rm = TRUE),
    median_price = median(data$price, na.rm = TRUE),
    mean_price = mean(data$price, na.rm = TRUE),
    max_price = max(data$price, na.rm = TRUE)
  )

  readr::write_csv(validation_summary, here::here("artifacts", "metrics", "validation_summary.csv"))

  log_step("Validation report created.")
  validation_agent
}

clean_housing_data <- function(data) {
  log_step("Cleaning data for modeling.")

  data %>%
    mutate(
      title = stringr::str_squish(stringr::str_to_title(title)),
      town = stringr::str_squish(stringr::str_to_title(town)),
      state = stringr::str_squish(stringr::str_to_title(state))
    ) %>%
    distinct() %>%
    filter(
      price > 0,
      bedrooms >= 0,
      bathrooms >= 0,
      toilets >= 0,
      parking_space >= 0
    )
}
