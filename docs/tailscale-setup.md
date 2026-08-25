# Tailscale Remote Access Setup

The Tailscale Operator is deployed by Flux into the `network` namespace. This guide
covers connecting it to your Tailscale account for private HTTPS access to homelab
services.

---

## 1. Create a Tailscale OAuth Client

1. Go to [login.tailscale.com/admin/settings/oauth](https://login.tailscale.com/admin/settings/oauth)
2. Create an OAuth client with scope: **Devices (Read & Write)**

---

## 2. Create the OAuth Secret

```bash
kubectl create secret generic operator-oauth -n network \
  --from-literal=client_id="<YOUR_CLIENT_ID>" \
  --from-literal=client_secret="<YOUR_CLIENT_SECRET>"
```

> **Tip:** For GitOps, you can also encrypt the secret with SOPS and commit it.
> See `kubernetes/apps/network/tailscale/oauth-secret.sops.yaml.example` for the format.

---

## 3. Expose Services via Tailscale

To expose any Kubernetes service with an automatic private HTTPS domain (via MagicDNS),
annotate its Service:

```yaml
metadata:
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: "longhorn"   # → https://longhorn.<tailnet>.ts.net
```

This gives you a trusted HTTPS endpoint accessible from any device on your tailnet.
