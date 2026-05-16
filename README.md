NixOS Proxmox Deployment

Quick reference guide for cloning, building, and deploying the n8n-server NixOS configuration to a Proxmox VE node.
0. Pre-Requisite (For Caddy Service Only)

Before building, if you are using the Caddy service, create the secrets directory and your Cloudflare environment file locally:

mkdir -p secrets
echo "CLOUDFLARE_DNS_API_TOKEN=" > secrets/cloudflare.env

Note: Add secrets/cloudflare.env to your .gitignore so your actual token isn't pushed to GitHub.
1. Clone the Config

git clone git@github.com:Deathraymind/n8n-server.git
cd n8n-server
2. Build the Image

Build the Proxmox .vma.zst backup image locally:
Ensure Git is tracking your secrets directory before running

git add secrets/

nixos-rebuild build-image --image-variant proxmox --flake .#proxmox-vm
3. Upload to Proxmox

Save the build path and upload the file to your Proxmox backup storage:
Capture the output path

BUILT_IMAGE=$(nixos-rebuild build-image --image-variant proxmox --flake .#proxmox-vm --print-out-paths)
Copy to Proxmox (Replace <PROXMOX_IP>)

scp $BUILT_IMAGE/*.vma.zst root@<PROXMOX_IP>:/var/lib/vz/dump/
4. Restore the VM

SSH into your Proxmox node and restore the file as a running VM:
1. SSH to Proxmox

ssh root@<PROXMOX_IP>
2. Go to backup directory

cd /var/lib/vz/dump/
3. Restore to a free VM ID (e.g., 105)

qmrestore vzdump-qemu-proxmox-vm.vma.zst 105 --unique true
4. Start the VM

qm start 105
