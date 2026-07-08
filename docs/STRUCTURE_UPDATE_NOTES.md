# Structure Update Notes

This version was reorganized to follow the report pattern used in `r-consortium-risk-conf-2026-demo-main` while preserving the Ghana R Conference 2026 workshop goal.

## Reference project conventions adopted

- Root-level `_quarto.yml` controls Quarto rendering.
- Root-level `report.qmd` is the main report assembly file.
- Modular narrative sections live in `qmd/_*.qmd`.
- Reusable report logic lives in `R/report_helpers.R` rather than inside the report body.
- `_targets.R` uses `tar_quarto()` so the report can be generated as a pipeline artifact.
- Report output is written to `artifacts/reports/`.

## Workshop goal preserved

The use case remains Nigerian real estate market intelligence for the talk/workshop:

> AI-Driven Predictive Analytics for Business Growth Using R: Insights from African Market Use Cases

The modeling lifecycle still covers import, validation, feature engineering, train/test split, resampling, model comparison, best-model selection, business price-gap screening, governance artifacts, optional MLflow tracking, model packaging, and scoring.

## Primary report files

- `_quarto.yml`
- `report.qmd`
- `qmd/_01_executive_summary.qmd`
- `qmd/_02_business_data_soundness.qmd`
- `qmd/_03_model_performance.qmd`
- `qmd/_04_business_governance.qmd`
- `R/report_helpers.R`

## Render command

```r
quarto::quarto_render("report.qmd", output_format = "html", execute_dir = here::here())
```

The expected output is:

```text
artifacts/reports/stakeholder_report.html
```
