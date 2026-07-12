{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.node;

  # Root pubkeys for every cluster node. Each host automatically
  # authorizes every key except its own (matched by hostname).
  # When node3 joins: add its key here, done.
  rootKeys = {
    node1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOnrq0rH4MjPgJc6jGr0gy8aLO1ew5NqHpEQnXGjWyqM root@node1";
    node2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICv8bQ88LagNgl17dyQiSnrlRGRcdrlS/o/wKpF0P76Y root@node2";
  };
in {
  imports = [
    ./common.nix
    ./qemu-incremental-backup-nightly.nix
    ./qemu-live-migrate.nix
    ./qemu-shutdown-migration.nix
  ];

  options.homelab.node = {
    lanAddress = lib.mkOption {
      type = lib.types.str;
      description = "Static IPv4 address on br0 (LAN).";
      example = "192.168.1.100";
    };

    bridgeInterface = lib.mkOption {
      type = lib.types.str;
      description = "Physical NIC enslaved to br0.";
      example = "eno1";
    };

    tengigAddress = lib.mkOption {
      type = lib.types.str;
      description = "This node's IP on the 10G direct link (without prefix).";
      example = "10.0.0.1";
    };

    tengigMac = lib.mkOption {
      type = lib.types.str;
      description = "Permanent MAC of the 10G NIC, used to match the interface.";
      example = "80:3f:5d:d3:ae:76";
    };

    peerIps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "10G-link IPs of all *other* cluster nodes.";
      example = ["10.0.0.2"];
    };

    evacuateTarget = lib.mkOption {
      type = lib.types.str;
      default = builtins.head cfg.peerIps;
      defaultText = lib.literalExpression "builtins.head config.homelab.node.peerIps";
      description = ''
        Node to live-migrate VMs to on shutdown, and the default target
        for qemu-live-migrate. Defaults to the first peer, which is fine
        for a two-node cluster; set explicitly once a third node exists.
      '';
    };

    vms = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["pelican-wings" "caddy" "pelican" "vaultwarden"];
      description = ''
        VMs this node is responsible for backing up / evacuating.
        Currently identical cluster-wide because replication is a
        symmetric two-node pair; override per-host if that changes.
      '';
    };
  };

  config = {
    ############################################################
    ## Networking
    ############################################################
    networking.useDHCP = false;
    networking.defaultGateway = lib.mkDefault "192.168.1.1";
    networking.nameservers = lib.mkDefault ["1.1.1.1" "8.8.8.8"];

    networking.bridges.br0.interfaces = [cfg.bridgeInterface];
    networking.interfaces.br0.ipv4.addresses = [
      {
        address = cfg.lanAddress;
        prefixLength = 24;
      }
    ];

    virtualisation.libvirtd.allowedBridges = ["br0" "virbr0"];

    # 10G direct node-to-node link (systemd-networkd)
    systemd.network.enable = true;
    systemd.network.wait-online.enable = false;
    systemd.network.networks."10-tengig" = {
      matchConfig.PermanentMACAddress = cfg.tengigMac;
      address = ["${cfg.tengigAddress}/24"];
      linkConfig.RequiredForOnline = "no";
    };

    ############################################################
    ## ZFS
    ############################################################
    environment.systemPackages = [pkgs.zfs];
    boot.supportedFilesystems = ["zfs"];
    boot.zfs.forceImportRoot = false;
    services.zfs.autoScrub.enable = true;
    services.zfs.trim.enable = true;

    # Local snapshots of the live VM datasets
    services.sanoid = {
      enable = true;
      datasets."vmpool/images" = {
        recursive = true; # covers all per-VM child datasets
        autosnap = true;
        autoprune = true;
        hourly = 24;
        daily = 7;
        weekly = 4;
        monthly = 0;
        yearly = 0;
      };
    };

    ############################################################
    ## Cluster services (backup / migration / evacuation)
    ############################################################
    services.qemu-incremental-backup-nightly = {
      enable = true;
      peerIps = cfg.peerIps;
      vms = cfg.vms;
      calendar = lib.mkDefault "*-*-* 04:30:00";
    };

    programs.qemu-live-migrate = {
      enable = true;
      defaultUser = "deathraymind";
      defaultIp = cfg.evacuateTarget;
    };

    services.qemu-evacuate-on-shutdown = {
      enable = true;
      vms = cfg.vms;
      targetIp = cfg.evacuateTarget;
    };

    ############################################################
    ## SSH / Nix
    ############################################################
    services.openssh.enable = true;
    nix.settings.experimental-features = ["nix-command" "flakes"];
    nix.settings.trusted-users = ["root" "deathraymind"];

    ############################################################
    ## Users
    ############################################################
    users.users.deathraymind = {
      isNormalUser = true;
      description = "Primary User";
      extraGroups = ["wheel" "qemu" "libvirtd" "kvm"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
      ];
      hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
    };

    # Every node's root authorizes every *other* node's root key,
    # so syncoid / migration works in any direction.
    users.users.root.openssh.authorizedKeys.keys =
      lib.attrValues
      (lib.filterAttrs (name: _: name != config.networking.hostName) rootKeys);

    ############################################################
    ## Firewall
    ############################################################
    networking.firewall.allowedTCPPorts = [2049]; # NFS
    networking.firewall.allowedTCPPortRanges = [
      {
        # libvirt live-migration data ports
        from = 49152;
        to = 49215;
      }
    ];

    system.stateVersion = "25.05";
  };
}
