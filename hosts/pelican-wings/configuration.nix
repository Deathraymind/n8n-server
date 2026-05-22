{
  pkgs,
  lib,
  ...
}: {
  boot.loader.grub.enable = true;

  # --- NETWORKING CONFIGURATION ---
  networking.hostName = "pelican-node1";
  networking.firewall.allowedTCPPorts = [8080 2022];
  networking.networkmanager.enable = true;
  networking.useDHCP = pkgs.lib.mkDefault true;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # --- PROXMOX ISO DRIVE MOUNT FIX ---
  fileSystems."/mnt/configdrive" = {
    device = "/dev/sr0";
    fsType = "iso9660";
    options = ["ro" "nofail"];
  };

  # --- CLOUD-INIT CONFIGURATION ---
  services.cloud-init = {
    enable = true;
    network.enable = true;

    settings = {
      datasource_list = ["NoCloud" "ConfigDrive"];
      datasource = {
        NoCloud = {
          seedfrom = "/mnt/configdrive/";
        };
      };
    };

    config = ''
      cloud_init_modules:
        - migrator
        - seed_random
        - bootcmd
        - growpart
        - resizefs
        - set_hostname
        - update_hostname
        - update_etc_hosts
        - ca_certs
        - rsyslog
        - users_groups
        - ssh
      cloud_config_modules:
        - write_files
      cloud_final_modules:
        - final-message
    '';
  };

  # --- NIXOS MANAGED PERMISSIONS & DIRECTORY SANITIZATION ---
  systemd.tmpfiles.rules = [
    "d /var/secrets 0755 root root - -"
    "d /var/secrets/pelican 0755 root root - -"

    # Force the token files to be globally readable to prevent permission blocks
    "z /var/secrets/pelican/token_id 0644 root root - -"
    "z /var/secrets/pelican/token 0644 root root - -"
  ];

  # --- FORCE SERVICE BOOT ORDER ---
  # Ensures the wings service delays initialization until cloud-final writes the tokens
  systemd.services.pelican-wings.after = ["cloud-final.service"];
  systemd.services.pelican-wings.wants = ["cloud-final.service"];

  # --- VIRTUALIZATION & ACCESS ---
  services.qemuGuest.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # --- USER CONFIGURATION ---
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };

  # --- SYSTEM PACKAGES ---
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
  ];

  # --- PELICAN WINGS ---
  services.pelican.wings = {
    enable = true;
    openFirewall = true;
    uuid = "3b523cae-aa23-401c-8a24-2b18486dd199";
    remote = "https://panel.deathraymind.net";
    tokenIdFile = "/var/secrets/pelican/token_id";
    tokenFile = "/var/secrets/pelican/token";
    api.ssl.enable = false;
  };

  # --- SYSTEM BACKENDS & CONFIG ---
  virtualisation.docker.enable = true;
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
