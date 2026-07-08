# MLflow tracking guide

## Local no-Docker option

Docker is not required for the core workshop workflow. To run MLflow locally without Docker, install the Python MLflow CLI:

```bash
python -m pip install mlflow
```

Then in RStudio run:

```r
source("scripts/08_start_local_mlflow.R")
Sys.setenv(MLFLOW_TRACKING_URI = "http://127.0.0.1:5001")
source("scripts/03_run_mlflow_tracking.R")
```

Open `http://127.0.0.1:5001`. If MLflow is not available, the project writes a local fallback ledger and the workflow can continue.

---

# MLflow Experiment Tracking Guide

This workshop includes MLflow as the experiment tracking layer for the Nigeria real-estate predictive analytics project.

## What MLflow tracks

The R workflow logs the current modelling run after the fast or full lifecycle has produced artifacts. The MLflow run records:

- experiment name;
- run name;
- champion model;
- champion RMSE, MAE, and R-squared;
- RMSE, MAE, and R-squared for each compared model;
- parameters such as use case, target, resampling strategy, and models compared;
- tags describing the workflow stage and artifact location.

The project uses `R/08_mlflow_tracking.R`, which talks to the MLflow REST API directly. This is intentionally robust for workshop delivery because it avoids some version differences in the R MLflow client.

## Local non-Docker workflow

Open one terminal from the project root and start MLflow manually:

```bash
mlflow server \
  --backend-store-uri ./mlruns \
  --default-artifact-root ./mlruns \
  --host 127.0.0.1 \
  --port 5001
```

Then, in R:

```r
Sys.setenv(MLFLOW_TRACKING_URI = "http://127.0.0.1:5001")
source("scripts/01_run_fast_workshop.R")
source("scripts/03_run_mlflow_tracking.R")
```

Open the UI at:

```text
http://127.0.0.1:5001
```

## Docker Compose workflow

From the project root:

```bash
docker compose up -d mlflow-ui
```

Open the UI at:

```text
http://127.0.0.1:5001
```

If you also use the RStudio container:

```bash
docker compose up -d
```

Then open RStudio at:

```text
http://127.0.0.1:8787
```

Login details:

```text
Username: rstudio
Password: workshop
```

Inside the RStudio container, run:

```r
source("scripts/01_run_fast_workshop.R")
source("scripts/03_run_mlflow_tracking.R")
```

The container uses this tracking URI automatically:

```text
http://mlflow-ui:5000
```

## Fallback behavior

If MLflow is not reachable, the project writes a local fallback ledger:

```text
artifacts/metrics/mlflow_fallback_experiment_ledger.csv
```

This prevents the workshop from failing just because the tracking server is unavailable. The facilitator can still teach the experiment tracking concept using the fallback ledger and rerun MLflow logging after the UI starts.

## Recommended live-demo sequence

1. Explain why experiment tracking matters.
2. Start the MLflow UI.
3. Run the fast workshop lifecycle.
4. Run MLflow logging.
5. Refresh the MLflow UI.
6. Show the experiment, run name, metrics, parameters, and tags.
7. Return to the Quarto report and explain how stakeholder reporting and experiment tracking complement each other.
