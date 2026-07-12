# Parent dataset for all VM images, mounted at /var/lib/libvirt/images
sudo zfs create -o mountpoint=/var/lib/libvirt/images vmpool/images

# Per-VM child datasets
sudo zfs create vmpool/images/pelican-wings
sudo zfs create vmpool/images/nas
