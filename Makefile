.DEFAULT_GOAL := help

TALOS_DIR     := talos
NODE_IP       := 192.168.18.100
CLUSTER_NAME  := homelab
TALOS_VERSION := v1.10.0

.PHONY: help iso secrets generate apply bootstrap kubeconfig reset

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

iso: ## Print link to download Talos ISO for baremetal
	@echo "Download the Talos ISO for baremetal (metal-amd64.iso) from:"
	@echo "  https://factory.talos.dev/?version=$(TALOS_VERSION)"
	@echo ""
	@echo "Flash to USB:"
	@echo "  sudo dd if=metal-amd64.iso of=/dev/sdX bs=4M status=progress && sync"

secrets: ## Generate cluster secrets (run once — output is gitignored)
	@mkdir -p $(TALOS_DIR)
	talosctl gen secrets --output-file $(TALOS_DIR)/secrets.yaml

generate: ## Generate machine config from secrets + patches
	talosctl gen config $(CLUSTER_NAME) https://$(NODE_IP):6443 \
	  --with-secrets $(TALOS_DIR)/secrets.yaml \
	  --config-patch-control-plane @$(TALOS_DIR)/patches/controlplane.yaml \
	  --config-patch @$(TALOS_DIR)/patches/install.yaml \
	  --output $(TALOS_DIR)/ \
	  --force
	@echo ""
	@echo "Generated: $(TALOS_DIR)/controlplane.yaml, $(TALOS_DIR)/talosconfig"

apply: ## Apply machine config to node (use --insecure on first boot)
	talosctl apply-config \
	  --talosconfig $(TALOS_DIR)/talosconfig \
	  --nodes $(NODE_IP) \
	  --file $(TALOS_DIR)/controlplane.yaml \
	  --insecure

bootstrap: ## Bootstrap etcd (run once after node reboots with config applied)
	talosctl bootstrap \
	  --talosconfig $(TALOS_DIR)/talosconfig \
	  --nodes $(NODE_IP)

kubeconfig: ## Fetch kubeconfig and merge into ~/.kube/homelab.yaml
	@mkdir -p ~/.kube
	talosctl kubeconfig ~/.kube/homelab.yaml \
	  --talosconfig $(TALOS_DIR)/talosconfig \
	  --nodes $(NODE_IP) \
	  --merge
	@chmod 600 ~/.kube/homelab.yaml
	@echo ""
	@echo "Cluster ready. Run:"
	@echo "  export KUBECONFIG=~/.kube/homelab.yaml"
	@echo "  kubectl get nodes -o wide"

reset: ## Factory reset the node (DESTRUCTIVE — wipes disk and reinstalls)
	talosctl reset \
	  --talosconfig $(TALOS_DIR)/talosconfig \
	  --nodes $(NODE_IP) \
	  --graceful=false \
	  --reboot
