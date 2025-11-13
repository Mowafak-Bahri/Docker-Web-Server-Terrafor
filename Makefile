.PHONY: init plan apply destroy

init:
	terraform -chdir=terraform init

plan:
	terraform -chdir=terraform plan

apply:
	terraform -chdir=terraform apply -auto-approve

destroy:
	terraform -chdir=terraform destroy -auto-approve
