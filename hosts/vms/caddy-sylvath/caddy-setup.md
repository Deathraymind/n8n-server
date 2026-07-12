create the nix image in a raw format with the following command nixos-generate
--flake .#caddy -f raw

then run this qemu-img convert -f raw -O qcow2\
/nix/store/..../nixos.img\
caddy.qcow2

copy the image to the node scp caddy.qcow2
deathraymind@192.168.1.100:/var/lib/libvirt/images/

then create the vm by sshing into the node and running

virt-install\
--name caddy\
--memory 2048\
--vcpus 2\
--disk /var/lib/libvirt/images/caddy.qcow2\
--import\
--os-variant linux2022\
--network bridge=br0\
--noautoconsole

1. Create the same YAML as user-data: bashcat << 'EOF' > user-data #cloud-config
   write_files:

- path: /var/secrets/cloudflare.env permissions: '0600' owner: root:root
  content: | CLOUDFLARE_DNS_API_TOKEN=randomtoken
- path: /var/secrets/pelican/app.key permissions: '0640' owner: root:root
  content: | base64:3mY7bX9fS2kK4pQ5vWxN8zP1R4sT6uVwXyZ0A1B2C3D=
- path: /var/secrets/pelican/dbpassword permissions: '0640' owner: root:root
  - path: /var/secrets/pelican/redispassword permissions: '0640' owner:
    root:root content: goon1234!!

  - path: /var/secrets/pelican/mailpassword permissions: '0640' owner: root:root
    content: good1234!!

  content: goon1234!! runcmd:
- chown -R root:pelican-panel /var/secrets/pelican
- chmod 750 /var/secrets/pelican
- chmod 640 /var/secrets/pelican/* EOF

2. Create meta-data: bashcat << 'EOF' > meta-data instance-id: pelican
   local-hostname: pelican EOF

3. Pack into ISO: nix-shell -p cdrkit --run "mkisofs -output pelican-secrets.iso
   -volid cidata -joliet -rock user-data meta-data"

4. In virt-manager: Open your VM → Add Hardware → Storage Browse to
   pelican-secrets.iso Device type: CDROM Finish and boot
