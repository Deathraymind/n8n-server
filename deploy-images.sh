#!/usr/bin/env bash
set -e # Exit immediately if any command fails
# make sure there is a ssh key on the machine  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.144
# --- GLOBAL CONFIGURATION ---
PROXMOX_IP="192.168.1.144"
PROXMOX_USER="root"
STORAGE_POOL="nvme"

# --- VM CONFIGURATION ARRAY ---
HOSTS=(
   #"caddy:160:Caddy-ReverseProxy:4096:+100G"
   "pelican:161:Pelican-Backend:4096:+150G"
  # "pelican-wings:162:Pelican-Wings:4096:+50G"
)

# --- EXECUTION ---
for entry in "${HOSTS[@]}"; do
  # Parse the expanded colon-separated string
  IFS=":" read -r FLAKE_ATTR VMID VM_NAME RAM_SIZE DISK_ADD <<< "$entry"
  
  echo "================================================="
  echo "Processing: $FLAKE_ATTR"
  echo "VM ID:       $VMID"
  echo "VM Name:     $VM_NAME"
  echo "RAM:         $RAM_SIZE"
  echo "Disk Add:    $DISK_ADD"
  echo "================================================="

  # 1. Run your exact working build command
  echo "Building Proxmox image..."
  nixos-rebuild build-image --image-variant proxmox --flake .#"$FLAKE_ATTR"
  
  # Resolve the store path via the 'result' symlink nixos-rebuild leaves behind
  BUILD_PATH=$(readlink -f result)
  
  # Find the actual .vma.zst file inside that directory
  VMA_FILE=$(find "$BUILD_PATH" -name "*.vma.zst" -print -quit)
  VMA_FILENAME=$(basename "$VMA_FILE")

  # 2. Copy it over to Proxmox
  echo "Uploading image to Proxmox..."
  scp "$VMA_FILE" "$PROXMOX_USER@$PROXMOX_IP:/var/lib/vz/dump/"

  # 3. Restore and customize on Proxmox via SSH
  echo "Provisioning VM on Proxmox host..."
  ssh "$PROXMOX_USER@$PROXMOX_IP" << EOF
   if qm status $VMID >/dev/null 2>&1; then
      echo "VM $VMID exists. Stopping and purging old instance..."
      qm stop $VMID || true
      qm unlock $VMID || true
      qm destroy $VMID --purge 1
    fi 
    # Check if the VM already exists before attempting a restore
    if qm status $VMID >/dev/null 2>&1; then
      echo "VM $VMID already exists. Skipping raw image restore to protect your data."
    else
      echo "VM $VMID does not exist. Restoring base image..."
      qmrestore /var/lib/vz/dump/$VMA_FILENAME $VMID --storage $STORAGE_POOL
    fi
   echo "Creating empty target shell configuration..."
    qm create $VMID --name "$VM_NAME" --memory $RAM_SIZE --net0 virtio,bridge=vmbr0 
    # Customize VM Name, RAM, and boot device while the VM is offline
    echo "Applying hardware specs (Name: $VM_NAME, RAM: $RAM_SIZE)..."
    qm set $VMID --name "$VM_NAME" --memory "$RAM_SIZE" --boot order=virtio0 --agent enabled=1
    
    # Resize disk dynamically based on configuration array
    # Using '|| true' because Proxmox will error if you try to add space that already exists
    echo "Resizing disk by $DISK_ADD..."
    qm resize $VMID virtio0 $DISK_ADD || true
    
    # Start the VM back up
    echo "Starting VM..."
    qm start $VMID
EOF

  # Clean up the local 'result' symlink so the next loop cycle handles it cleanly
  rm result

  echo "Initial deployment complete for $FLAKE_ATTR ($VM_NAME)."
  echo "------------------------------------------------"
done
