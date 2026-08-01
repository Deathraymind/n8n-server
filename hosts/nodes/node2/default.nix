{...}: {
  imports = [
    ../../../modules/ishikori/qemu-node.nix
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
  fileSystems."/srv/share" = {
    # Replace with the actual IP of the other server and the path it exports
    device = "192.168.1.100:/srv/share";
    fsType = "nfs";

    # These options are crucial: they mount the share "on demand"
    # so your VM server doesn't freeze during boot if the remote server is offline.
    options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=600"];
  };
  programs.qemu-live-export.outputDir = "/srv/share/cold-export";
}
