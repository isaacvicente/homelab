.DEFAULT_GOAL := help

ANSIBLE_DIR := ansible
TOFU_DIR    := opentofu

# MinIO credentials — set as env var MINIO_PASS
MINIO_HOST ?= $(shell grep -E '^[0-9]' $(ANSIBLE_DIR)/inventory/inventory.ini 2>/dev/null | awk '{print $$1}' | head -1)
MINIO_USER ?= minioadmin
MINIO_PASS ?= $(error MINIO_PASS is not set. Run: export MINIO_PASS=<your-minio-password>)

.PHONY: help setup init plan apply destroy kubeconfig schematic vault-create

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Run Ansible — configure host (MinIO .deb + Incus + bridge + ZFS)
	cd $(ANSIBLE_DIR) && ansible-playbook setup.yaml --ask-vault-pass

init: ## Initialize OpenTofu with MinIO remote backend
	cd $(TOFU_DIR) && tofu init \
	  -backend-config="endpoint=http://$(MINIO_HOST):9000" \
	  -backend-config="access_key=$(MINIO_USER)" \
	  -backend-config="secret_key=$(MINIO_PASS)" \
	  -reconfigure

plan: ## Preview infrastructure changes
	cd $(TOFU_DIR) && tofu plan

apply: ## Provision VMs + bootstrap Kubernetes cluster
	cd $(TOFU_DIR) && tofu apply

destroy: ## Destroy all Incus VMs (does not affect host config)
	cd $(TOFU_DIR) && tofu destroy

kubeconfig: ## Copy kubeconfig to ~/.kube/homelab.yaml
	@mkdir -p ~/.kube
	cp $(TOFU_DIR)/kubeconfig.yaml ~/.kube/homelab.yaml
	@chmod 600 ~/.kube/homelab.yaml
	@echo ""
	@echo "Cluster is ready. Run:"
	@echo "  export KUBECONFIG=~/.kube/homelab.yaml"
	@echo "  kubectl get nodes"

schematic: ## Instructions for generating Talos schematic ID
	@echo ""
	@echo "  1. Open: https://factory.talos.dev"
	@echo "  2. Under 'System Extensions', add: siderolabs/qemu-guest-agent"
	@echo "  3. Click 'Generate'"
	@echo "  4. Copy the schematic ID into opentofu/terraform.tfvars:"
	@echo "       talos_schematic_id = \"<paste-id-here>\""
	@echo ""

vault-create: ## Create Ansible Vault file for MinIO credentials
	@mkdir -p $(ANSIBLE_DIR)/group_vars/all
	ansible-vault create $(ANSIBLE_DIR)/group_vars/all/vault.yaml
