{...}: {
  imports = [
    ../../modules/qemu-node.nix
    ./hardware.nix
  ];

  networking.hostName = "node3";
  networking.hostId = "4c27bb3b"; # must be unique per node (ZFS)

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  homelab.node = {
    lanAddress = "10.0.0.8";
    bridgeInterface = "enp2s0";
    tengigAddress = "10.0.0.1";
    tengigMac = "80:3f:5d:d3:ae:76";
    peerIps = ["10.0.0.2"];
  };
}
