{...}: {
  imports = [
    ../../modules/qemu-node.nix
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
  services.nfs.server = {
    enable = true;
    exports = ''
      /export/data 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
    '';
  };

  fileSystems."/export/data" = {
    device = "/data";
    options = ["bind"];
    fsType = "ext4";
  };
}
