# AI-Driven Predictive Analytics for Business Growth Using R
### Insights from African Market Use Cases — Real Estate Market Intelligence in Nigeria

**Ghana R Conference 2026 Workshop**  
*Theme: Ghana Digitalization Drive — Transforming the AI Ecospace of Ghana with R Software*

---

## What This Workshop Is About

This repository demonstrates a complete, practical machine-learning lifecycle in R using a real business problem: **real estate market intelligence in Nigeria**.

The goal is not only to train a model. The goal is to show how R can support an end-to-end business decision workflow:

```text
raw data → validation → feature engineering → model training → model comparison
→ business screening → model packaging → experiment tracking → stakeholder report
```

The same pattern can be adapted to health, agriculture, finance, governance, marketing, and public-sector analytics use cases.

By the end of the workshop, you will be able to:

- Validate and clean raw market/listing data in R
- Engineer features that capture business signal
- Train and compare linear regression, random forest, and XGBoost models
- Interpret RMSE, MAE, and R² for model comparison
- Use model predictions to flag pricing gaps for human review
- Package a champion model for reuse
- Score new property records using the packaged model
- Generate a reproducible Quarto stakeholder report
- Optionally track model experiments with MLflow

---

## Who This Is For

This workshop is for analysts, researchers, data scientists, students, and business professionals with **basic R proficiency**.

You should be comfortable running R scripts and reading `tidyverse`-style code. Prior machine-learning experience is helpful but not required.

---

## Local Setup: No Docker Required

The organizers have requested a setup path that allows participants to run the project **locally on their own system without Docker**. This is now the default workshop path.

Docker is not required for the main workflow.

---

## Before the Workshop

Please complete these steps before the session.

### 1. Install R

Install **R 4.3 or later**.

Download R from CRAN:

```text
https://cran.r-project.org/
```

Recommended:

```text
R 4.4.x or later
```

Windows users may also need **Rtools** if packages need to compile from source:

```text
https://cran.r-project.org/bin/windows/Rtools/
```

---

### 2. Install RStudio or Positron

Install either RStudio Desktop or Positron.

```text
https://posit.co/download/rstudio-desktop/
```

---

### 3. Install Quarto

Quarto is required to render the final stakeholder report.

Download Quarto:

```text
https://quarto.org/docs/get-started/
```

Confirm Quarto is available by running this in your system terminal:

```bash
quarto check
```

Or from R:

```r
quarto::quarto_check()
```

---

### 4. Clone the repository

```bash
git clone https://github.com/BWOlatunji/ai_driven_predictive_analytics_for_business_growth_ghana_rconf2026.git
cd <your_repo_name>
```

Replace `<your_username>` and `<your_repo_name>` with the actual GitHub repository details.

---

### 5. Open the project in RStudio

Open the `.Rproj` file if available.

If there is no `.Rproj` file, open RStudio and set the working directory to the project root.

You should be in the folder that contains files such as:

```text
README.md
scripts/
R/
data/
artifacts/
report.qmd
_quarto.yml
```

---

### 6. Install or restore R packages

If the repository includes `renv.lock`, run:

```r
install.packages("renv")
renv::restore()
```

If you are not using `renv`, run the setup script:

```r
source("scripts/00_setup.R")
```

The setup script loads required packages and creates the expected project folders.

---

## Quick Start: Run the Workshop Locally

After setup, run the complete workshop lifecycle:

```r
source("scripts/00_setup.R")
source("scripts/01_run_complete_workshop.R")
```

This is the recommended route for participants during the live session.

The complete workflow is designed to complete within a reasonable workshop timeframe while still demonstrating the full machine-learning lifecycle.

---

## Expected Outputs

After the complete workflow completes, check these files:

```text
artifacts/metrics/model_comparison.csv
artifacts/metrics/best_model_metrics.csv
artifacts/predictions/business_screening_candidates.csv
artifacts/figures/model_comparison_rmse.png
artifacts/figures/predicted_vs_actual.png
artifacts/figures/price_gap_distribution.png
artifacts/reports/stakeholder_report.html
```

Open the final stakeholder report:

```r
browseURL("artifacts/reports/stakeholder_report.html")
```

You can also inspect the model leaderboard:

```r
readr::read_csv("artifacts/metrics/model_comparison.csv")
```

The champion model for the current workflow is **XGBoost**, although exact metrics may vary slightly by system, package version, and tuning run.

---

## Use `targets` for a Reproducible Pipeline

If you want to run the project as a reproducible pipeline, use:

```r
source("scripts/00_setup.R")
targets::tar_make()
```

To visualize the pipeline:

```r
targets::tar_visnetwork()
```

If you encounter stale cache issues, reset the pipeline cache:

```r
targets::tar_destroy()
```

Then rerun:

```r
targets::tar_make()
```

---


## Optional: Package and Score New Data

After the model has been trained and evaluated, package the champion model:

```r
source("scripts/04_package_model.R")
```

This creates:

```text
artifacts/model_package/best_model.rds
artifacts/model_package/model_card.md
artifacts/model_package/feature_contract.csv
artifacts/model_package/model_metadata.json
artifacts/model_package/deployment_notes.md
```

Score new sample property records:

```r
source("scripts/05_score_new_data.R")
```

Expected scoring output:

```text
artifacts/predictions/scored_new_properties.csv
artifacts/governance/scoring_manifest.csv
```

---

## Repository Structure

The project is organized as follows:

```text
.
├── R/
│   ├── 00_packages.R
│   ├── 01_import.R
│   ├── 02_validate.R
│   ├── 03_prepare_features.R
│   ├── 04_split_recipe.R
│   ├── 05_train_models.R
│   ├── 06_evaluate_rank.R
│   ├── 07_log_artifacts.R
│   ├── 08_mlflow_tracking.R
│   ├── 09_package_model.R
│   ├── 10_predict.R
│   ├── report_helpers.R
│   └── utils.R
├── scripts/
│   ├── 00_setup.R
│   ├── 01_run_complete_workshop.R
│   ├── 02_run_full_workshop.R
│   ├── 03_run_mlflow_tracking.R
│   ├── 04_package_model.R
│   ├── 05_score_new_data.R
│   └── 07_render_report.R
├── qmd/
│   └── report sections used by report.qmd
├── data/
│   ├── raw/
│   ├── interim/
│   ├── processed/
│   └── new/
├── artifacts/
│   ├── metrics/
│   ├── models/
│   ├── model_package/
│   ├── predictions/
│   ├── figures/
│   ├── reports/
│   ├── governance/
│   └── mlflow/
├── report.qmd
├── _quarto.yml
├── _targets.R
├── renv.lock
└── README.md
```

---

## Workshop Flow

| Stage | What You Will Do | Main Files |
|---|---|---|
| 1. Setup | Load packages and create folders | `scripts/00_setup.R`, `R/00_packages.R`, `R/utils.R` |
| 2. Import | Read raw housing CSV data | `R/01_import.R` |
| 3. Validate | Run data checks and create validation report | `R/02_validate.R` |
| 4. Feature engineering | Create modelling and business features | `R/03_prepare_features.R` |
| 5. Split and recipes | Create train/test split, folds, and model-specific recipes | `R/04_split_recipe.R` |
| 6. Model training | Train linear regression, random forest, and XGBoost | `R/05_train_models.R` |
| 7. Evaluation | Rank models and select champion model | `R/06_evaluate_rank.R` |
| 8. Business screening | Create price-gap signals and candidate lists | `R/06_evaluate_rank.R` |
| 9. Reporting | Render stakeholder-ready Quarto report | `R/07_log_artifacts.R`, `report.qmd`, `qmd/` |
| 10. MLflow optional | Track metrics, params, and champion model | `R/08_mlflow_tracking.R` |
| 11. Packaging optional | Package model and governance artifacts | `R/09_package_model.R` |
| 12. Scoring optional | Score new property records | `R/10_predict.R` |

---

## What the Model Predicts

The model is trained to predict:

```text
log_price
```

This means model metrics such as RMSE and MAE are calculated on the log-transformed price scale.

For business interpretation, predictions are converted back to estimated Naira price using:


So the workflow produces both:

```text
predicted_log_price       # model-scale output
predicted_price_naira     # business-readable output
```

---

## Understanding the Price Gap

The project calculates:

```text
price_gap = actual_price - predicted_price
```

Interpretation:

| Price Gap | Meaning |
|---:|---|
| Negative | Actual listed price is below the model estimate |
| Near zero | Actual listed price is close to the model estimate |
| Positive | Actual listed price is above the model estimate |

Example:

```text
Actual price: ₦80 million
Predicted price: ₦100 million
Price gap: -₦20 million
Signal: Potential opportunity for review
```

Important: this is **not automatic investment advice**. It is a decision-support signal for further human review.

---

## Why This Matters Beyond Real Estate

The workflow pattern is reusable:

```text
validate → engineer → train → compare → screen for actionable gaps → package → report
```

Examples:

- **Health:** flagging unusual patient risk scores for review
- **Agriculture:** identifying farms underperforming relative to predicted yield
- **Finance:** detecting mispriced assets or credit-risk anomalies
- **Governance:** surfacing service-delivery gaps against expected benchmarks
- **Marketing:** identifying customer segments with unexpected churn or revenue gaps

The most important takeaway is the workflow pattern, not just the real estate use case.

---

## Clean Repository Policy

As a participant, you should receive a clean repository. You will generate these outputs yourself by running:

```r
source("scripts/00_setup.R")
source("scripts/01_run_complete_workshop.R")
```

This allows everyone to confirm that the full workflow is working on their system.

---

## Troubleshooting

### Problem: `scripts/00_setup.R` not found

Make sure you are in the project root folder.

Check:

```r
list.files()
```

You should see:

```text
scripts
R
data
artifacts
report.qmd
```

---

### Problem: package installation fails on Windows

Install Rtools:

```text
https://cran.r-project.org/bin/windows/Rtools/
```

Then restart R and run:

```r
renv::restore()
```

or:

```r
source("scripts/00_setup.R")
```

---

### Problem: Quarto report does not render

Check Quarto:

```r
quarto::quarto_check()
```

Then manually render:

```r
quarto::quarto_render(
  input = "report.qmd",
  output_format = "html",
  execute_dir = here::here(),
  quiet = FALSE
)
```

Also check:

```text
artifacts/reports/quarto_render_diagnostic.txt
```

---

## After the Workshop

Below are recommended next steps:

- Fork the repository
- Replace the Nigeria housing data with your own sector data
- Modify the feature engineering logic
- Keep the lifecycle pattern
- Re-render the stakeholder report
- Add the project to your portfolio

---


## Acknowledgments

Presented at **Ghana R Conference 2026**, organized by **The Ghana R Users Community**.
