# Workshop Delivery Guide: Version 2

## Positioning

The workshop is not only about predicting house prices. It demonstrates how R can support a business-facing machine learning lifecycle for African market intelligence.

Use this framing:

> We start with a clear business problem, build a reproducible predictive model, compare candidate models with resampling, track experiments, package the champion model, and prepare it for scoring new business records.

## Recommended live flow

### 1. Business problem and dataset context

Explain that Nigerian real estate is high-value, location-sensitive, and affected by fragmented market data.

### 2. Data validation

Show `validation_report.html`.

Message:

> Before modeling, we validate whether the data is structurally fit for use.

### 3. Feature engineering

Explain engineered signals such as total rooms, parking availability, location grouping, and ratios.

### 4. Resampling

Explain:

> A single split can be lucky or unlucky. Cross-validation gives a more reliable basis for model selection.

Show:

```r
readr::read_csv("artifacts/metrics/resampling_summary.csv")
```

### 5. Hyperparameter experimentation

Explain:

> We are not training one arbitrary model. We are testing model settings under a controlled validation process.

Show:

```r
readr::read_csv("artifacts/metrics/best_hyperparameters.csv")
readr::read_csv("artifacts/metrics/hyperparameter_experiments.csv")
```

### 6. Model comparison

Show:

```r
readr::read_csv("artifacts/metrics/model_comparison.csv")
```

Message:

> The champion model is selected using evidence, not preference.

### 7. MLflow

Run or show:

```r
source("scripts/03_run_mlflow_tracking.R")
```

Message:

> MLflow gives every experiment a memory: parameters, metrics, artifacts, and model evidence.

### 8. Model package

Run:

```r
source("scripts/04_package_model.R")
```

Show:

```r
fs::dir_tree("artifacts/model_package")
```

Message:

> A production-ready model needs more than a fitted object. It needs metadata, expected inputs, performance evidence, and limitations.

### 9. Deployment-ready scoring

Run:

```r
source("scripts/05_score_new_data.R")
```

Show:

```r
readr::read_csv("artifacts/predictions/scored_new_properties.csv")
```

Message:

> The model becomes useful when it can score new business records.

### 10. Workflow management

Show `_targets.R`.

Message:

> Scripts are excellent for teaching. Pipelines are better for production workflow management.
