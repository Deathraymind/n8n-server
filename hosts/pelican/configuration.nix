{
  pkgs,
  lib,
  ...
}: {
  boot.loader.grub.enable = true;

  # --- NETWORKING CONFIGURATION ---
  networking.hostName = "Game-Server";

  # --- CLOUD-INIT PROXMOX FIX ---
  services.cloud-init = {
    enable = true;
    network.enable = true;

    settings = {
      datasource_list = ["NoCloud" "ConfigDrive"];
    };

    # Separated correctly so NixOS activates the write_files engine
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

  networking.networkmanager.enable = true;
  networking.useDHCP = pkgs.lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [80 443];
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # --- NIXOS MANAGED PERMISSIONS & DIRECTORY SANITIZATION ---
  # --- NIXOS MANAGED PERMISSIONS & DIRECTORY SANITIZATION ---
  systemd.tmpfiles.rules = [
    "d /var/secrets 0755 root root - -"
    "d /var/secrets/pelican 0755 root root - -" # Opened up directory access

    # Force existing files to be readable by the services
    "z /var/secrets/pelican/app.key 0644 root root - -"
    "z /var/secrets/pelican/dbpassword 0644 root root - -"
    "z /var/secrets/pelican/mailpassword 0644 root root - -"
    "z /var/secrets/pelican/redispassword 0644 root root - -"
  ]; # --- FORCE SERVICE BOOT ORDER ---
  systemd.services.redis-pelican-panel.after = ["cloud-final.service"];
  systemd.services.redis-pelican-panel.wants = ["cloud-final.service"];

  systemd.services.pelican-panel-setup.after = ["cloud-final.service" "redis-pelican-panel.service"];
  systemd.services.pelican-panel-setup.wants = ["cloud-final.service"];

  systemd.services.pelican-queue.after = ["cloud-final.service" "pelican-panel-setup.service"];
  systemd.services.pelican-queue.wants = ["cloud-final.service"];

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

  # --- PELICAN PANEL ---
  services.pelican.panel = {
    enable = true;
    app.url = "https://panel.deathraymind.net";
    app.keyFile = "/var/secrets/pelican/app.key";
    database.passwordFile = "/var/secrets/pelican/dbpassword";
    redis.passwordFile = "/var/secrets/pelican/redispassword";
    mail.passwordFile = "/var/secrets/pelican/mailpassword";
  };

  # --- SYSTEM BACKENDS & CONFIG ---
  virtualisation.docker.enable = true;
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
