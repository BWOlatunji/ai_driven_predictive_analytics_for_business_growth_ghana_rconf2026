setup:
	Rscript scripts/00_setup.R

fast:
	Rscript scripts/01_run_fast_workshop.R

full:
	Rscript scripts/02_run_full_lifecycle.R

package:
	Rscript scripts/04_package_model.R

score:
	Rscript scripts/05_score_new_data.R

report:
	Rscript scripts/07_render_report.R

mlflow:
	Rscript scripts/03_run_mlflow_tracking.R

mlflow-local:
	Rscript scripts/08_start_local_mlflow.R

targets:
	Rscript scripts/06_run_targets_pipeline.R

mlflow-ui:
	docker compose up -d mlflow-ui

docker-build:
	docker compose build

docker-up:
	docker compose up -d

docker-down:
	docker compose down
