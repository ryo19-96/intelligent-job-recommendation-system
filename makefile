.PHONY: lint fmt all terraform_init_dev terraform_plan_dev terraform_apply_dev
# === Ruff ===

lint:
	poetry run ruff check

fmt:
	poetry run ruff check --fix

all: fmt lint

# === terraform ===

terraform_init_dev:
	cd terraform/dev && terraform init

terraform_plan_dev:
	cd terraform/dev && terraform plan

terraform_apply_dev:
	cd terraform/dev && terraform apply