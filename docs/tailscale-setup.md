# Tailscale Operator & SOPS GitOps Setup Guide

This guide provides an end-to-end walkthrough for deploying and operating the **Tailscale Operator** using **Flux CD** and **SOPS + age** encryption.

With this setup, all secrets (including your Tailscale OAuth credentials) remain encrypted in Git and are decrypted in-cluster by Flux.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph Local["Development Machine"]
        A["Tailscale Admin Console<br/>(OAuth Client Credentials)"] --> B["Create oauth-secret.sops.yaml"]
        B --> C["sops -e -i oauth-secret.sops.yaml<br/>(Encrypted via .sops.yaml)"]
        C --> D["git commit & push"]
        E["~/.config/sops/age/keys.txt"] -->|task sops-secret| F["sops-age Secret<br/>(namespace: flux-system)"]
    end

    subgraph Cluster["Kubernetes (Baremetal Talos)"]
        D -->|Git Pull| G["Flux source-controller"]
        G --> H["Flux kustomize-controller"]
        F -->|Decryption Key| H
        H -->|Decrypted Plaintext| I["operator-oauth Secret<br/>(namespace: network)"]
        H -->|Installs| J["Tailscale Operator Pod"]
        I -->|Credentials| J
        J -->|Registers to Tailnet| K["Tailscale Cloud Control Plane"]
    end
```

---

## Step 1: Create Tailscale OAuth Client

1. Open the [Tailscale Admin Console → OAuth Clients](https://login.tailscale.com/admin/settings/oauth).
2. Click **Generate OAuth client**.
3. Under **Scopes**, select:
   - **Devices**: `Read & Write` (allows the operator to add and manage machines on your tailnet)
4. Under **Tags**, ensure you assign a tag (e.g. `tag:k8s-operator`).
   > **Note:** If your tailnet requires ACL tags for OAuth clients, make sure the tag exists in your Tailscale ACL policy under `tagOwners`.
5. Click **Generate client** and copy the **Client ID** and **Client Secret**.

---

## Step 2: Inject the age Decryption Key into Flux

Flux requires your private `age` key inside the cluster (in the `flux-system` namespace) to decrypt secrets.

Run the Taskfile target:

```bash
task sops-secret
```

*Or run the `kubectl` command directly:*

```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt \
  --dry-run=client -o yaml | kubectl apply -f -
```

Verify that the secret was created:

```bash
kubectl get secret sops-age -n flux-system
```

---

## Step 3: Configure Flux for In-Cluster SOPS Decryption

When Flux reconciles manifests from Git, its `Kustomization` CR must have decryption enabled.

In `kubernetes/flux-system/gotk-sync.yaml` (managed by Flux bootstrap), ensure the `Kustomization` includes the `decryption` section:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./kubernetes
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

---

## Step 4: Create and Encrypt the Tailscale OAuth Secret

1. Copy the example file in `kubernetes/apps/network/tailscale/`:

```bash
cp kubernetes/apps/network/tailscale/oauth-secret.sops.yaml.example \
   kubernetes/apps/network/tailscale/oauth-secret.sops.yaml
```

2. Edit `kubernetes/apps/network/tailscale/oauth-secret.sops.yaml` and paste your actual Tailscale credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: operator-oauth
  namespace: network
type: Opaque
stringData:
  client_id: "tskey-client-xxxxxxxxxxxx"
  client_secret: "tskey-secret-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

3. Encrypt the file in-place using SOPS:

```bash
sops -e -i kubernetes/apps/network/tailscale/oauth-secret.sops.yaml
```

> **How it works:** Thanks to `encrypted_regex: '^(data|stringData)$'` in `.sops.yaml`, SOPS only encrypts the values inside `stringData`. The Kubernetes metadata (`apiVersion`, `kind`, `metadata`, `type`) remains in plaintext:
>
> ```yaml
> apiVersion: v1
> kind: Secret
> metadata:
>   name: operator-oauth
>   namespace: network
> type: Opaque
> stringData:
>   client_id: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
>   client_secret: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
> sops:
>   ...
> ```

4. Add `oauth-secret.sops.yaml` to `kubernetes/apps/network/tailscale/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: network
resources:
  - namespace.yaml
  - helmrepository.yaml
  - helmrelease.yaml
  - oauth-secret.sops.yaml
```

---

## Step 5: Enable Network Apps in GitOps

Ensure that `./network` is uncommented in `kubernetes/apps/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./storage
  - ./network
```

Commit and push your changes to GitHub:

```bash
git add kubernetes/apps/
git commit -m "feat(network): enable tailscale operator with encrypted oauth secret"
git push
```

Flux will automatically pull the commit, decrypt `oauth-secret.sops.yaml`, apply the secret to the `network` namespace, and install the `tailscale-operator` Helm release.

---

## Step 6: Expose Homelab Services via Tailscale

Once the Tailscale Operator is running, you can expose any Kubernetes Service or Ingress directly to your tailnet with automatic HTTPS certificates.

### Pattern A: Expose via Ingress (Recommended for Automatic HTTPS)

To expose an HTTP/web application with automatic Let's Encrypt HTTPS certificates (`https://<hostname>.<tailnet>.ts.net`), create an `Ingress` with `ingressClassName: tailscale`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: default
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - nginx      # -> https://nginx.<tailnet>.ts.net
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
```

The Tailscale Operator will:
1. Spin up a lightweight L7 proxy pod in the `network` namespace.
2. Join your tailnet as a device named `nginx`.
3. Automatically provision a trusted Let's Encrypt TLS certificate for `https://nginx.<tailnet-name>.ts.net`.
4. Listen on port 443 (HTTPS) and automatically redirect HTTP port 80 to HTTPS.

### Pattern B: Expose a Service Directly (Layer 4 TCP / Plain Stream)

For non-HTTP services or raw TCP streams without TLS termination, annotate the `Service` directly:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: raw-tcp-service
  namespace: default
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: "raw-service"
spec:
  type: ClusterIP
  selector:
    app: raw-service
  ports:
    - name: tcp-stream
      port: 9000
      targetPort: 9000
```

To access the entire Kubernetes Pod CIDR or node LAN from your Tailnet without per-service proxies, configure a `Connector` resource:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: Connector
metadata:
  name: homelab-subnet-router
  namespace: network
spec:
  hostname: homelab-subnet-router
  routes:
    - "192.168.18.0/24"    # Physical LAN
    - "10.244.0.0/16"      # Flannel Pod Network
```

---

## Step 7: Access Kubernetes Cluster from Tailscale (`apiServerProxyConfig`)

The HelmRelease is configured with `apiServerProxyConfig.mode: "true"` and `apiServerProxyConfig.allowImpersonation: "true"`.

When enabled, the Tailscale Operator joins your Tailnet as an authenticating reverse proxy for the Kubernetes API server (e.g. named `tailscale-operator`).

### Configure Local `kubectl` Access

From any machine connected to your Tailnet:

1. Use the Tailscale CLI to configure your `kubeconfig`:

```bash
tailscale configure kubeconfig tailscale-operator
```

2. Switch to the newly created context:

```bash
kubectl --context=tailscale-operator get nodes -o wide
```

3. (Optional) Set as default context:

```bash
kubectl config use-context tailscale-operator
```

> **How it works:** Tailscale verifies your Tailscale identity when connecting, intercepts the request, and proxies it to the Kubernetes API server using Kubernetes user impersonation headers (`Impersonate-User`). Standard Kubernetes RBAC applies based on your Tailscale user identity.

---

## Step 8: Manage the Baremetal Talos Node over Tailscale (`siderolabs/tailscale`)

To manage your physical host with `talosctl` even if Kubernetes, CNI, or Flux is down, Tailscale runs as a native **Talos Linux System Extension** (`siderolabs/tailscale`).

```mermaid
flowchart TD
    A["talosctl (Laptop / Phone)"] -->|Tailscale WireGuard Mesh| B["homelab (Talos Host Node)"]
    B -->|Port 50000| C["Talos API (machined)"]
    B -->|Port 6443| D["Kube API Server"]
```

### 1. Create a Reusable Tailscale Auth Key

1. In [Tailscale Admin Console → Settings → Keys](https://login.tailscale.com/admin/settings/keys), click **Generate auth key**.
2. Settings:
   - **Reusable**: `Yes`
   - **Tags**: `tag:k8s-operator`
   - **Pre-authorized**: `Yes`
3. Copy the generated key (`tskey-auth-...`).

### 2. Configure & Encrypt `talenv.sops.yaml`

1. Copy the example file:
   ```bash
   cp talos/talenv.sops.yaml.example talos/talenv.sops.yaml
   ```
2. Paste your auth key in `talos/talenv.sops.yaml`:
   ```yaml
   tailscale_auth_key: "tskey-auth-kxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   ```
3. Encrypt it with SOPS:
   ```bash
   sops -e -i talos/talenv.sops.yaml
   ```

### 3. Generate and Apply Machine Configuration

1. Render the updated Talos machine configuration:
   ```bash
   task generate
   ```

2. Upgrade the running node (or apply during initial installation):
   ```bash
   task upgrade
   ```

### 4. Manage with `talosctl` over Tailscale

Once authenticated, the node joins your Tailnet as **`homelab`**. You can manage it from anywhere:

```bash
# View dashboard over Tailscale:
talosctl --talosconfig talos/clusterconfig/talosconfig --nodes homelab dashboard

# Check system logs:
talosctl --talosconfig talos/clusterconfig/talosconfig --nodes homelab dmesg

# Reboot node out-of-band:
talosctl --talosconfig talos/clusterconfig/talosconfig --nodes homelab reboot
```

---

## Verification & Troubleshooting

### Check Flux Decryption & Reconciliation

```bash
# Check status of Kustomization
flux get kustomizations

# View controller logs if decryption fails
flux logs --level=error --kind=Kustomization
```

### Check Tailscale Operator Pods & Secret

```bash
# Verify the decrypted secret exists in the network namespace
kubectl get secret operator-oauth -n network

# Check Operator status
kubectl get pods -n network -l app.kubernetes.io/name=tailscale-operator

# View Operator logs
kubectl logs -n network -l app.kubernetes.io/name=tailscale-operator -f
```

### Check Devices in Tailscale Admin

Visit [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines) — you should see:
- **`homelab`**: The baremetal Talos Linux physical host.
- **`tailscale-operator`**: The in-cluster Kubernetes API proxy.
- **`nginx` / `longhorn`**: The individual exposed application Ingresses.
