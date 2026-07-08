# Artifact logging ---------------------------------------

write_run_manifest <- function(mode, ranking_results) {
  log_step("Writing run manifest for governance and reproducibility.")

  fs::dir_create(here::here("artifacts", "metrics"))
  fs::dir_create(here::here("artifacts", "governance"))

  manifest <- tibble::tibble(
    project_name = project_name,
    use_case_name = use_case_name,
    conference_topic = "AI-Driven Predictive Analytics for Business Growth Using R: Insights from African Market Use Cases",
    workflow_version = "v2-production-aware",
    run_mode = mode,
    run_timestamp = as.character(Sys.time()),
    best_model = ranking_results$best_model_name,
    best_rmse = ranking_results$best_summary$rmse,
    best_mae = ranking_results$best_summary$mae,
    best_rsq = ranking_results$best_summary$rsq,
    r_version = R.version.string
  )

  readr::write_csv(manifest, here::here("artifacts", "metrics", "run_manifest.csv"))
  readr::write_csv(manifest, here::here("artifacts", "governance", "run_manifest.csv"))

  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(
      as.list(manifest[1, ]),
      here::here("artifacts", "governance", "run_manifest.json"),
      auto_unbox = TRUE,
      pretty = TRUE
    )
  }

  manifest
}

render_stakeholder_report <- function() {
  log_step("Rendering Quarto stakeholder report.")

  report_input <- here::here("report.qmd")
  report_output_dir <- here::here("artifacts", "reports")
  report_output_file <- here::here("artifacts", "reports", "stakeholder_report.html")
  legacy_report_file <- here::here("reports", "stakeholder_report.html")
  diagnostic_file <- here::here("artifacts", "reports", "quarto_render_diagnostic.txt")

  fs::dir_create(report_output_dir)

  if (!fs::file_exists(report_input)) {
    warning("Root report.qmd not found. Skipping report render.")
    return(invisible(FALSE))
  }

  if (fs::file_exists(report_output_file)) {
    fs::file_delete(report_output_file)
  }

  render_ok <- tryCatch(
    {
      quarto::quarto_render(
        input = report_input,
        output_format = "html",
        execute_dir = here::here(),
        quiet = FALSE
      )
      TRUE
    },
    error = function(e) {
      msg <- paste0(
        "Quarto report could not be rendered.

",
        "Error message:
",
        conditionMessage(e),
        "

Troubleshooting checks to run in the R console:
",
        "quarto::quarto_version()
",
        "quarto::quarto_check()
",
        "quarto::quarto_render('report.qmd', output_format = 'html', execute_dir = here::here(), quiet = FALSE)
"
      )
      writeLines(msg, diagnostic_file)
      warning("Quarto report could not be rendered. See: ", diagnostic_file)
      FALSE
    }
  )

  if (!isTRUE(render_ok)) {
    return(invisible(FALSE))
  }

  if (!fs::file_exists(report_output_file)) {
    msg <- paste0(
      "Quarto render finished, but the expected HTML output was not found at:
",
      report_output_file,
      "

Check the output-file setting in report.qmd and output-dir in _quarto.yml."
    )
    writeLines(msg, diagnostic_file)
    warning(msg)
    return(invisible(FALSE))
  }

  # Keep a legacy copy for participants who previously opened reports/stakeholder_report.html.
  fs::dir_create(here::here("reports"))
  fs::file_copy(path = report_output_file, new_path = legacy_report_file, overwrite = TRUE)

  log_step(glue::glue("Stakeholder report rendered: {report_output_file}"))
  invisible(TRUE)
}
