{...}: {
  imports = [
    ../../../modules/ishikori/qemu-node.nix
    ./hardware.nix
  ];

  networking.hostName = "node1";
  networking.hostId = "4c27bb3b"; # must be unique per node (ZFS)

  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-Samsung_SSD_840_Series_S19HNSAD511826K";
  };

  homelab.node = {
    lanAddress = "192.168.1.100";
    bridgeInterface = "eno1";
    tengigAddress = "10.0.0.1";
    tengigMac = "80:3f:5d:d3:ae:76";
    peerIps = ["10.0.0.2"];
  };

  ############################################################
  ## node1-only: NFS export of tank/data
  ############################################################

  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=10de:1f82,10de:10fa"
  ];

  # bind in initrd so nouveau never touches it
  boot.initrd.kernelModules = ["vfio_pci" "vfio" "vfio_iommu_type1"];

  boot.blacklistedKernelModules = ["nouveau"];

  boot.zfs.extraPools = ["tank"];

  # the 3TB raidz2 share — nothing to do with VM storage
  fileSystems."/srv/share" = {
    device = "tank/data";
    fsType = "zfs";
    options = ["nofail"];
  };

  services.zfs.autoScrub.enable = true;
  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/share 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
    '';
  };
}
