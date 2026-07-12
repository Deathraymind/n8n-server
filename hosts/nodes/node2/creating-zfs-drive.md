# ZFS NVMe Pool on NixOS — Non-Declarative Steps

Reference for converting a whole NVMe drive into a ZFS pool for VM storage. Pool
creation and dataset creation are **imperative** (persistent on-disk state, not
managed by NixOS config). Everything else (mounts, snapshots, replication) is
declarative.

## Per-host values to change each time

- **Pool device**: use the `/dev/disk/by-id/nvme-...` name (stable across
  reboots), NOT `/dev/nvme0n1`
- **hostId**: each host needs a UNIQUE 8-hex-char `networking.hostId` (ZFS
  requires it)
- Node1 example: pool `vmpool`, hostId `4c27bb3b`
- Node2 example: same pool name `vmpool` (fine — pools are per-host), different
  hostId

## 1. Find the disk's stable by-id name

```bash
ls -l /dev/disk/by-id/ | grep nvme
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINT
```

Pick the `nvme-<MODEL>_<SERIAL>` symlink.

## 2. Clear any existing filesystem/LVM signatures

If the disk was ext4, just unmount it. If it was an **LVM physical volume**
(`FSTYPE=LVM2_member`), remove the LVM stack first:

```bash
# inspect what's on it
sudo pvs ; sudo vgs ; sudo lvs
# remove the volume group that lives on this PV (replace <vg>)
sudo vgremove <vg>
sudo pvremove /dev/nvme0n1
# nuke any leftover signatures
sudo wipefs -a /dev/nvme0n1
```

If the disk currently holds a mounted filesystem:

```bash
sudo systemctl stop libvirtd
sudo umount /var/lib/libvirt/images   # if applicable
```

## 3. Create the pool (imperative — one time)

```bash
sudo zpool create -f \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O mountpoint=none \
  vmpool /dev/disk/by-id/nvme-<MODEL>_<SERIAL>

sudo zpool status vmpool
zpool list
```

Option meanings: `ashift=12` = 4K sectors (correct for NVMe); `compression=lz4`
= nearly free space saving; `atime=off` = skip access-time writes; `xattr=sa` =
efficient extended attributes; `mountpoint=none` = pool root doesn't mount,
datasets do.

## 4. Create the dataset (imperative — one time)

```bash
sudo zfs create -o mountpoint=/var/lib/libvirt/images vmpool/images
zfs list
```

## 5. Declare in NixOS config (declarative)

In `hardware.nix` (or host config), reference the dataset by NAME, not device
path:

```nix
fileSystems."/var/lib/libvirt/images" = {
  device = "vmpool/images";
  fsType = "zfs";
};
```

Ensure these are also present (usually already there if tank exists):

```nix
boot.supportedFilesystems = [ "zfs" ];
networking.hostId = "<UNIQUE-8-HEX>";   # MUST differ per host
services.zfs.autoScrub.enable = true;
services.zfs.trim.enable = true;
environment.systemPackages = [ pkgs.zfs ];
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

## 6. Verify

```bash
zfs list
mount | grep libvirt
sudo systemctl restart libvirtd
virsh list --all
```

## Notes

- ZFS pools/datasets are NOT created by NixOS config — they are on-disk state.
  NixOS only imports and mounts them. Steps 3 and 4 are unavoidably imperative.
- The `fileSystems` block is technically redundant with the dataset's own
  `mountpoint` property, but declaring it makes the mount explicit in config and
  enforces boot ordering (libvirtd waits for the mount).
