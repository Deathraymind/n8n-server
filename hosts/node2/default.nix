{...}: {
  imports = [
    ../../modules/qemu-node.nix
    ./hardware.nix
  ];

  networking.hostName = "node2";
  networking.hostId = "73a55545"; # must be unique per node (ZFS)

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  homelab.node = {
    lanAddress = "192.168.1.99";
    bridgeInterface = "enp3s0f0";
    tengigAddress = "10.0.0.2";
    tengigMac = "80:3f:5d:d3:ae:ed";
    peerIps = ["10.0.0.1"];
  };
}
