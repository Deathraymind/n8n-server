{
  pkgs,
  lib,
  config,
  ...
}: {
  boot.loader.grub.enable = true;
  # --- NETWORKING CONFIGURATION ---
  networking.hostName = "Game-Server";
  # --- CLOUD-INIT PROXMOX FIX ---
  networking.networkmanager.enable = true;
  networking.useDHCP = pkgs.lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [80 443];
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # --- SOPS SECRETS ---
  sops.defaultSopsFile = ../../secrets/pelican.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  sops.secrets."pelican/app_key" = {
    owner = "pelican";
    group = "pelican";
    mode = "0400";
  };
  sops.secrets."pelican/db_password" = {
    owner = "pelican";
    group = "pelican";
    mode = "0400";
  };
  sops.secrets."pelican/redis_password" = {
    owner = "pelican";
    group = "pelican";
    mode = "0400";
  };
  sops.secrets."pelican/mail_password" = {
    owner = "pelican";
    group = "pelican";
    mode = "0400";
  };

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
    app.keyFile = config.sops.secrets."pelican/app_key".path;
    database.passwordFile = config.sops.secrets."pelican/db_password".path;
    redis.passwordFile = config.sops.secrets."pelican/redis_password".path;
    mail.passwordFile = config.sops.secrets."pelican/mail_password".path;
  };

  # --- SYSTEM BACKENDS & CONFIG ---
  virtualisation.docker.enable = true;
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
