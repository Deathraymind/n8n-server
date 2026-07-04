{
  modulesPath,
  pkgs,
  lib,
  ...
}: {
  imports = [../../modules/common.nix ./hardware.nix ../../modules/qemu-incremental-backup-nightly.nix ./qemu-live-migrate.nix];
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  networking.hostName = "node2";
  networking.bridges.br0.interfaces = ["enp3s0f0"];
  virtualisation.libvirtd.allowedBridges = ["br0" "virbr0"];
  networking.interfaces.br0.ipv4.addresses = [
    {
      address = "192.168.1.99";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = ["1.1.1.1" "8.8.8.8"];
  ## Drive Share/nvme
  services.qemu-incremental-backup-nightly = {
    enable = true;

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
  programs.qemu-live-migrate = {
    enable = true;
    defaultUser = "deathraymind";
  };
  fileSystems."/var/lib/libvirt/images" = {
    device = "vmpool/images";
    fsType = "zfs";
  };

  networking.hostId = "73a55545";
  environment.systemPackages = [
    pkgs.zfs
  ];

  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOnrq0rH4MjPgJc6jGr0gy8aLO1ew5NqHpEQnXGjWyqM root@node1" # node2's pubkey
  ];

  networking.firewall.allowedTCPPorts = [2049];
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 49152;
      to = 49215;
    }
  ];
  system.stateVersion = "25.05";

  # Syncoid
  # node2 config
  services.syncoid.enable = true; # creates the syncoid user

  users.users.syncoid = {
    isSystemUser = true;
    group = "syncoid";
    home = "/var/lib/syncoid";
    createHome = lib.mkDefault true;
    shell = pkgs.bashInteractive; # needs a real shell for zfs recv over ssh
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP03e7L0xaM3o3kV8ygPmoOKdzVjjjxzfZ+UtIz8tuA2 syncoid@node1" # ← the pubkey from step 1
    ];
  };
  users.groups.syncoid = {};
}
