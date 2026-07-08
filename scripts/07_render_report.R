# Render stakeholder report ---------------------------------------------------
# Run after scripts/01_run_complete_workshop.R or scripts/02_run_full_lifecycle.R.

source("R/00_packages.R")
load_required_packages()

source("config/project_config.R")
source("R/utils.R")
source("R/07_log_artifacts.R")

render_stakeholder_report()
