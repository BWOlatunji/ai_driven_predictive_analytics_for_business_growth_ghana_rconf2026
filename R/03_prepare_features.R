# Feature engineering ------------------------------------------------

prepare_housing_features <- function(data, output_path = processed_data_path) {
  log_step("Preparing business-relevant features.")

  model_ready <- data %>%
    mutate(
      price_raw = price,
      price_winsorized = winsorize_numeric(price),
      log_price = log1p(price_winsorized),
      total_rooms = bedrooms + bathrooms + toilets,
      total_wet_rooms = bathrooms + toilets,
      bathroom_bedroom_ratio = safe_divide(bathrooms, bedrooms),
      toilet_bedroom_ratio = safe_divide(toilets, bedrooms),
      parking_per_bedroom = safe_divide(parking_space, bedrooms),
      has_parking = factor(if_else(parking_space > 0, "Has parking", "No parking")),
      market_hub = case_when(
        state %in% c("Lagos", "Abuja") ~ "Prime commercial hub",
        state %in% c("Rivers", "Oyo", "Ogun") ~ "Major growth corridor",
        TRUE ~ "Emerging market"
      ),
      market_hub = factor(market_hub),
      title = factor(title),
      town = factor(town),
      state = factor(state),
      price_band = dplyr::ntile(log_price, 5),
      price_band = factor(price_band)
    )

  readr::write_csv(model_ready, output_path)

  market_summary <- model_ready %>%
    group_by(state, town) %>%
    summarise(
      listings = n(),
      median_price = median(price_raw, na.rm = TRUE),
      median_log_price = median(log_price, na.rm = TRUE),
      median_bedrooms = median(bedrooms, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(listings), desc(median_price))

  readr::write_csv(market_summary, here::here("artifacts", "metrics", "exploratory_market_summary.csv"))

  price_distribution_plot <- model_ready %>%
    ggplot(aes(x = log_price)) +
    geom_histogram(bins = 40) +
    labs(
      title = "Distribution of Nigerian House Prices",
      subtitle = "Log-transformed price is used because property prices are usually skewed",
      x = "Log price",
      y = "Number of listings"
    )

  save_plot_artifact(price_distribution_plot, here::here("artifacts", "figures", "price_distribution.png"))

  state_price_plot <- model_ready %>%
    group_by(state) %>%
    summarise(
      median_price = median(price_raw, na.rm = TRUE),
      listings = n(),
      .groups = "drop"
    ) %>%
    slice_max(order_by = listings, n = 15) %>%
    ggplot(aes(x = reorder(state, median_price), y = median_price)) +
    geom_col() +
    coord_flip() +
    scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_short_scale())) +
    labs(
      title = "Median Property Price by State",
      subtitle = "Top states by listing count",
      x = "State",
      y = "Median price"
    )

  save_plot_artifact(state_price_plot, here::here("artifacts", "figures", "median_price_by_state.png"))

  log_step(glue::glue("Prepared {nrow(model_ready)} model-ready rows."))
  model_ready
}
