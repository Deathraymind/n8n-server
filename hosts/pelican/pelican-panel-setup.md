this is the main manual step you will have to preform when setting up pelican
panel to create the image for deployment use nixos-generator to create a raw
image

nix-generate --flake #.pelican -f raw then run qemu-img convert -f raw -O qcow2
/nix/store/..../nixos.img pelican.qcow2

scp pelican.qcow2 deathraymind@192.168.1.100:~/pelican.qcow2

virt-install --name pelican-wings --memory 2048 --vcpus 2 --disk
/var/lib/libvirt/images/pelican-wings.qcow2 --import --os-variant linux2022
--network bridge=br0 --noautoconsole

sudo -u pelican-panel pelican-cli p:user:make

follow the steps, if you get a redis error it didnt start because you didnt
follow the steps in secerts.md
