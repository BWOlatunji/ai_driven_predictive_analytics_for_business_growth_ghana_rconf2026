# Importing raw data -----------------------------------------------------

import_raw_housing_data <- function(raw_path = raw_data_path, output_path = interim_data_path) {
  log_step("Importing raw CSV data.")

  if (!fs::file_exists(raw_path)) {
    stop(glue::glue("Raw data file not found: {raw_path}"), call. = FALSE)
  }

  houses_raw <- readr::read_csv(
    raw_path,
    show_col_types = FALSE,
    col_types = cols(
      bedrooms = col_double(),
      bathrooms = col_double(),
      toilets = col_double(),
      parking_space = col_double(),
      title = col_character(),
      town = col_character(),
      state = col_character(),
      price = col_double()
    )
  ) %>%
    janitor::clean_names()

  skim_output <- skimr::skim(houses_raw)
  readr::write_csv(as_tibble(skim_output), here::here("artifacts", "metrics", "raw_data_skim.csv"))

  readr::write_csv(houses_raw, output_path)

  log_step(glue::glue("Imported {nrow(houses_raw)} rows and {ncol(houses_raw)} columns."))
  houses_raw
}
