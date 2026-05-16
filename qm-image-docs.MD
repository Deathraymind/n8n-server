build the image with

nixos-rebuild build-image --image-variant proxmox --flake .#pelican

then scp it 

scp /nix/store/dprglc19i7h0i6s8j2a14bibsk3dcq6c-vzdump-qemu-nixos-26.05.20260510.da5ad66/vzdump-qemu-nixos-26.05.20260510.da5ad66.vma.zst root@192.168.1.144:/var/lib/vz/dump/vzdump-caddy.vma.zst


then ssh into the prxomox server and run 

qmrestore /var/lib/vz/dump/vzdump-qemu-nixos-26.05.20260510.da5ad66.vma.zst  101 --unique true 


then run 

 qm resize 120 virtio0 +200G 

 to increase the disk size
