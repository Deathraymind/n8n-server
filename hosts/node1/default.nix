{
  modulesPath,
  pkgs,
  ...
}: {
  imports = [../../modules/common.nix ./hardware.nix ../../modules/qemu-incremental-backup-nightly.nix ../../modules/qemu-live-migrate.nix];
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-Samsung_SSD_840_Series_S19HNSAD511826K";
  };
  networking.hostName = "node1";
  networking.bridges.br0.interfaces = ["eno1"];
  virtualisation.libvirtd.allowedBridges = ["br0" "virbr0"];
  networking.interfaces.br0.ipv4.addresses = [
    {
      address = "192.168.1.100";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = ["1.1.1.1" "8.8.8.8"];
  programs.qemu-live-migrate = {
    enable = true;
    defaultUser = "deathraymind";
    defaultIp = "192.168.1.99";
  };
  services.qemu-incremental-backup-nightly = {
    enable = true;
    peerIp = "192.168.1.99";
    # List the VMs hosted on THIS specific node that need backing up
    vms = [
      "pelican-wings"
      "caddy"
      "pelican"
      # "pihole"
    ];

    # Optional: Override the default 3:00 AM run time if you want
    calendar = "*-*-* 04:30:00";
  };
  # Disable DHCP on eno1 since br0 takes over

  services.openssh.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["root" "deathraymind"];

  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel" "qemu" "libvirtd" "kvm"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICv8bQ88LagNgl17dyQiSnrlRGRcdrlS/o/wKpF0P76Y root@node2" # node2's pubkey
  ];
  ## Drive Share
  networking.hostId = "4c27bb3b";
  environment.systemPackages = [
    pkgs.zfs
  ];
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

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

  networking.firewall.allowedTCPPorts = [2049];
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 49152;
      to = 49215;
    }
  ];
  system.stateVersion = "25.05";
  # Syncoid
  # ---- Snapshots (local, hourly, on node1's live VMs) ----
  services.sanoid = {
    enable = true;
    datasets."vmpool/images" = {
      recursive = true; # covers all per-VM child datasets automatically
      autosnap = true;
      autoprune = true;
      hourly = 24; # keep 24 hourly
      daily = 7; # keep 7 daily
      weekly = 4; # keep 4 weekly
      monthly = 0;
      yearly = 0;
    };
  };

  # ---- Replication (push node1's VMs to node2 as backup) ----
  services.syncoid = {
    enable = true;
    interval = "hourly";
    sshKey = "/var/lib/syncoid/.ssh/id_syncoid";
    commonArgs = ["--no-sync-snap"]; # use sanoid's snapshots, don't make extra ones
    commands."vmpool/images" = {
      source = "vmpool/images";
      target = "syncoid@192.168.1.99:vmpool/backup/node1/images";
      recursive = true; # ships all child datasets (caddy, pelican, etc.)
    };
  };
}
