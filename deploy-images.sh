#!/usr/bin/env bash
#
# deploy-vm.sh
#
# Builds a NixOS flake output into a raw disk image, converts it to qcow2,
# copies it to a libvirt host, and creates the VM with virt-install.
#
# Run this from the directory containing your flake.nix.

set -euo pipefail

# --- Sanity-check required tools are available locally ---
for cmd in nixos-generate qemu-img scp ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command '$cmd' not found in PATH. Aborting." >&2
    exit 1
  fi
done

# --- Ask what to build/deploy ---
read -rp "Which flake output do you want to build/deploy (e.g. caddy): " FLAKE_ATTR
if [[ -z "$FLAKE_ATTR" ]]; then
  echo "No flake attribute given, aborting." >&2
  exit 1
fi

read -rp "VM name on the libvirt host [default: ${FLAKE_ATTR}]: " VM_NAME
VM_NAME="${VM_NAME:-$FLAKE_ATTR}"

read -rp "Target libvirt node (user@host), e.g. deathraymind@192.168.1.100: " NODE_TARGET
if [[ -z "$NODE_TARGET" ]]; then
  echo "No target node given, aborting." >&2
  exit 1
fi

read -rp "Memory in MB [2048]: " VM_MEMORY
VM_MEMORY="${VM_MEMORY:-2048}"

read -rp "vCPUs [2]: " VM_VCPUS
VM_VCPUS="${VM_VCPUS:-2}"

read -rp "Bridge network [br0]: " VM_NET
VM_NET="${VM_NET:-br0}"

read -rp "OS variant [linux2022]: " OS_VARIANT
OS_VARIANT="${OS_VARIANT:-linux2022}"

IMAGES_DIR="/var/lib/libvirt/images"
WORKDIR="$(mktemp -d)"
QCOW2_LOCAL="${WORKDIR}/${VM_NAME}.qcow2"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# --- Build the raw image ---
echo "==> Building raw image for flake .#${FLAKE_ATTR}"
GEN_OUTPUT="$(nixos-generate --flake ".#${FLAKE_ATTR}" -f raw | tail -n1)"

if [[ -z "$GEN_OUTPUT" || ! -e "$GEN_OUTPUT" ]]; then
  echo "Could not determine nixos-generate output path. Got: '${GEN_OUTPUT}'" >&2
  exit 1
fi

RAW_IMG="$GEN_OUTPUT"
if [[ -d "$GEN_OUTPUT" ]]; then
  RAW_IMG="$(find "$GEN_OUTPUT" -maxdepth 1 -type f \( -name '*.img' -o -name '*.raw' \) | head -n1)"
fi

if [[ -z "$RAW_IMG" || ! -f "$RAW_IMG" ]]; then
  echo "Could not find a raw image inside ${GEN_OUTPUT}" >&2
  exit 1
fi

echo "==> Raw image: ${RAW_IMG}"

# --- Convert to qcow2 ---
echo "==> Converting to qcow2: ${QCOW2_LOCAL}"
qemu-img convert -f raw -O qcow2 "$RAW_IMG" "$QCOW2_LOCAL"

# --- Copy to the libvirt node ---
echo "==> Copying ${VM_NAME}.qcow2 to ${NODE_TARGET}:${IMAGES_DIR}/"
scp "$QCOW2_LOCAL" "${NODE_TARGET}:${IMAGES_DIR}/${VM_NAME}.qcow2"

# --- Create the VM on the node ---
echo "==> Creating VM '${VM_NAME}' on ${NODE_TARGET}"
ssh -t "$NODE_TARGET" \
  "sudo virt-install \
    --name '${VM_NAME}' \
    --memory '${VM_MEMORY}' \
    --vcpus '${VM_VCPUS}' \
    --disk '${IMAGES_DIR}/${VM_NAME}.qcow2' \
    --import \
    --os-variant '${OS_VARIANT}' \
    --network bridge='${VM_NET}' \
    --noautoconsole"

echo
echo "Done. VM '${VM_NAME}' should now be defined on ${NODE_TARGET}."
echo "Check with: ssh ${NODE_TARGET} 'sudo virsh list --all'"
