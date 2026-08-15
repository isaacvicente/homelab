.DEFAULT_GOAL := help

TALOS_DIR := talos
NODE_IP   := 192.168.18.100

.PHONY: help age-key secrets generate apply bootstrap kubeconfig flux-init reset

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

age-key: ## Generate age encryption key if none exists (~/.config/sops/age/keys.txt)
	@mkdir -p ~/.config/sops/age
	@if [ ! -f ~/.config/sops/age/keys.txt ]; then \
	  age-keygen -o ~/.config/sops/age/keys.txt; \
	  echo "New age key generated at ~/.config/sops/age/keys.txt"; \
	else \
	  echo "Existing age key found at ~/.config/sops/age/keys.txt"; \
	fi
	@echo ""
	@echo "Your age Public Key (paste this into .sops.yaml):"
	@age-keygen -y ~/.config/sops/age/keys.txt

secrets: ## Generate cluster secrets and encrypt with SOPS
	@mkdir -p $(TALOS_DIR)
	@if [ ! -f $(TALOS_DIR)/talsecret.sops.yaml ]; then \
	  echo "Generating $(TALOS_DIR)/talsecret.sops.yaml via talhelper..."; \
	  talhelper gensecret > $(TALOS_DIR)/talsecret.sops.yaml; \
	  sops -e -i $(TALOS_DIR)/talsecret.sops.yaml; \
	  echo "Secrets generated and encrypted."; \
	else \
	  echo "$(TALOS_DIR)/talsecret.sops.yaml already exists."; \
	fi

generate: ## Generate Talos machine configs from talconfig.yaml + talsecret.sops.yaml
	talhelper genconfig -c $(TALOS_DIR)/talconfig.yaml -s $(TALOS_DIR)/talsecret.sops.yaml -o $(TALOS_DIR)/clusterconfig
	@echo ""
	@echo "Generated machine configs in $(TALOS_DIR)/clusterconfig/"

apply: ## Apply generated config to node in maintenance mode (triggers install to disk)
	talhelper gencommand apply -c $(TALOS_DIR)/talconfig.yaml -o $(TALOS_DIR)/clusterconfig --insecure | bash

bootstrap: ## Bootstrap etcd on the node
	talhelper gencommand bootstrap -c $(TALOS_DIR)/talconfig.yaml -o $(TALOS_DIR)/clusterconfig | bash

kubeconfig: ## Fetch and merge admin kubeconfig to ~/.kube/homelab.yaml
	@mkdir -p ~/.kube
	talhelper gencommand kubeconfig -c $(TALOS_DIR)/talconfig.yaml -o $(TALOS_DIR)/clusterconfig | bash
	@echo ""
	@echo "Cluster is ready. Run:"
	@echo "  export KUBECONFIG=~/.kube/homelab.yaml"
	@echo "  kubectl get nodes -o wide"

flux-init: ## Bootstrap Flux CD into the cluster from this Git repository
	@echo "Bootstrapping Flux CD from Git..."
	flux bootstrap github \
	  --owner=isaacvicente \
	  --repository=homelab \
	  --branch=main \
	  --path=kubernetes/flux-system \
	  --personal

reset: ## Factory reset the physical node (DESTRUCTIVE — wipes disk)
	talosctl reset \
	  --talosconfig $(TALOS_DIR)/clusterconfig/talosconfig \
	  --nodes $(NODE_IP) \
	  --graceful=false \
	  --reboot
