# Running the workshop locally without Docker

This guide is for participants who want to run the Ghana R Conference 2026 workshop project directly on their own computer. Docker is optional.

## 1. Install local prerequisites

Install these before the workshop:

1. R 4.4 or newer
2. RStudio Desktop
3. Quarto Desktop
4. Rtools for Windows, if you are on Windows and R asks for compilation tools
5. Git, if you are cloning the repository

MLflow is optional for local execution. The core modelling workflow works without MLflow.

## 2. Open the project

Open `ghana_r_2026_ai_predictive_analytics_r.Rproj` in RStudio. This sets the project root correctly.

## 3. Install R packages

Run this once:

```r
source("scripts/00_setup.R")
```

This installs missing packages, loads the package bootstrap, and creates required folders under `data/` and `artifacts/`.

## 4. Run the complete workshop workflow

```r
source("scripts/01_run_complete_workshop.R")
```

This creates the main outputs:

```text
artifacts/metrics/model_comparison.csv
artifacts/metrics/best_model_metrics.csv
artifacts/models/best_model.rds
artifacts/predictions/business_screening_candidates.csv
artifacts/figures/model_comparison_rmse.png
artifacts/reports/stakeholder_report.html
```

## 5. Package the champion model

```r
source("scripts/04_package_model.R")
```

This writes the handoff bundle to:

```text
artifacts/model_package/
```

## 6. Score new properties

```r
source("scripts/05_score_new_data.R")
```

The scored output is written to:

```text
artifacts/predictions/scored_new_properties.csv
```

## 7. Render the report manually, if needed

The complete workflow already renders the report. To rerender it manually:

```r
source("scripts/07_render_report.R")
```

Open:

```text
artifacts/reports/stakeholder_report.html
```

## 8. Optional: run MLflow locally without Docker

The project can complete without MLflow. If MLflow is not running, the tracking script writes a local fallback ledger.

For a local MLflow UI, install the Python MLflow CLI first:

```bash
python -m pip install mlflow
```

Then in RStudio run:

```r
source("scripts/08_start_local_mlflow.R")
```

Open:

```text
http://127.0.0.1:5001
```

Then log the model run:

```r
Sys.setenv(MLFLOW_TRACKING_URI = "http://127.0.0.1:5001")
source("scripts/03_run_mlflow_tracking.R")
```

## 9. Troubleshooting

### Package installation fails on Windows

Install Rtools that matches your R version, restart RStudio, and rerun:

```r
source("scripts/00_setup.R")
```

### Quarto report does not render

Install Quarto Desktop, restart RStudio, and run:

```r
quarto::quarto_check()
source("scripts/07_render_report.R")
```

### MLflow does not open

MLflow is optional. Continue with the workshop. The command below will write a local fallback ledger if the server is unavailable:

```r
source("scripts/03_run_mlflow_tracking.R")
```

### The repository looks empty under artifacts

That is expected. Generated outputs are ignored by Git. Participants create them by running the workflow.
