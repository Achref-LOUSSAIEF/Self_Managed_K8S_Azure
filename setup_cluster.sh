#!/bin/bash
# =============================================================================
# Kubernetes Cluster Setup Script
# Run this locally after "terraform apply" completes.
# Prerequisites: kubectl, helm, ssh access to both VMs
# =============================================================================

set -euo pipefail

# ─── CONFIGURE THESE ─────────────────────────────────────────────────────────
CPLANE_IP=""        # e.g. "20.10.20.30"  (terraform output control_plane_public_ip)
WORKER_IP=""        # e.g. "20.10.20.31"  (terraform output worker_public_ip)
ADMIN_USER="azureuser"
SSH_KEY="~/.ssh/id_rsa"
# ─────────────────────────────────────────────────────────────────────────────

if [ -z "$CPLANE_IP" ] || [ -z "$WORKER_IP" ]; then
  echo "Set CPLANE_IP and WORKER_IP at the top of this script before running."
  exit 1
fi

SSH_CP="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${ADMIN_USER}@${CPLANE_IP}"
SSH_WK="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${ADMIN_USER}@${WORKER_IP}"

# =============================================================================
# STEP 1 — Control Plane: initialise the cluster
# =============================================================================
echo ""
echo "▶ [1/5] Initialising Kubernetes control plane on ${CPLANE_IP} ..."
$SSH_CP "sudo /usr/local/bin/k8s-control-plane-init.sh"

# =============================================================================
# STEP 2 — Fetch kubeconfig locally
# =============================================================================
echo ""
echo "▶ [2/5] Downloading admin.conf ..."
scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no \
  "${ADMIN_USER}@${CPLANE_IP}:admin.conf" ./admin.conf

export KUBECONFIG="$(readlink -f admin.conf)"
echo "   KUBECONFIG set to: $KUBECONFIG"

# Verify connectivity
kubectl get nodes

# =============================================================================
# STEP 3 — Get join credentials from control plane (never hardcode these)
# =============================================================================
echo ""
echo "▶ [3/5] Retrieving join token and CA hash from control plane ..."

JOIN_CMD=$($SSH_CP "sudo kubeadm token create --print-join-command")
# Parse the join command output: kubeadm join <endpoint> --token <token> --discovery-token-ca-cert-hash <hash>
API_ENDPOINT=$(echo "$JOIN_CMD" | awk '{print $3}')
TOKEN=$(echo "$JOIN_CMD"       | awk '{for(i=1;i<=NF;i++) if($i=="--token") print $(i+1)}')
CA_HASH=$(echo "$JOIN_CMD"     | awk '{for(i=1;i<=NF;i++) if($i=="--discovery-token-ca-cert-hash") print $(i+1)}')

echo "   API endpoint : $API_ENDPOINT"
echo "   Token        : $TOKEN"
echo "   CA hash      : $CA_HASH"

# =============================================================================
# STEP 4 — Worker: join the cluster
# =============================================================================
echo ""
echo "▶ [4/5] Joining worker node ${WORKER_IP} to the cluster ..."
$SSH_WK "sudo /usr/local/bin/k8s-worker-join.sh '${API_ENDPOINT}' '${TOKEN}' '${CA_HASH}'"

# Wait for worker to become Ready
echo "   Waiting for worker node to become Ready ..."
kubectl wait --for=condition=Ready node --all --timeout=120s

# =============================================================================
# STEP 5 — Control Plane: install cloud-provider-azure and Calico (CNI)
# =============================================================================
echo ""
echo "▶ [5/5] Installing cloud-provider-azure and Calico CNI ..."

$SSH_CP <<'REMOTE'
set -e

# cloud-provider-azure
helm install \
  --repo https://raw.githubusercontent.com/kubernetes-sigs/cloud-provider-azure/master/helm/repo \
  cloud-provider-azure \
  --generate-name \
  --set cloudControllerManager.clusterCIDR="192.168.0.0/16"

# Calico via Tigera operator — version pinned for K8s 1.29 compatibility
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update
helm install calico projectcalico/tigera-operator \
  --version v3.27.3 \
  -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico/values.yaml \
  --namespace tigera-operator \
  --create-namespace
REMOTE

echo ""
echo "Cluster setup complete!"
echo "   Use: export KUBECONFIG=$(readlink -f admin.conf)"
echo "   Then: kubectl get nodes"
