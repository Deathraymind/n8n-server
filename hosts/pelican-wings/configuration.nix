{
  pkgs,
  lib,
  ...
}: {
  boot.loader.grub.enable = true;
  # --- NETWORKING CONFIGURATION ---
  networking.hostName = "Game-Server";

  # Explicitly turn off NetworkManager if you want to use systemd-networkd
  networking.networkmanager.enable = true;
  networking.useDHCP = pkgs.lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [80];
  # Enable systemd-networkd for reliable static IP management
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # --- VIRTUALIZATION & ACCESS ---
  services.qemuGuest.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # --- USER CONFIGURATION ---
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel"]; # 'wheel' enables sudo

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com" # <-- Your public SSH key
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
  #services.pelican.panel = {
  #enable = true;
  #app.url = "https://panel.deathraymind.com";
  #app.keyFile = "/var/secrets/pelican/app.key";
  #database.passwordFile = "/var/secrets/pelican/dbpassword";
  #redis.passwordFile = "/var/secrets/pelican/redispassword";
  #mail.passwordFile = "/var/secrets/pelican/mailpassword";
  # };

  # --- PELICAN WINGS (Cleanly commented out so it doesn't break syntax) ---
  services.pelican.wings = {
    enable = true;
    openFirewall = true;
    uuid = "your-node-uuid";
    remote = "https://panel.deathraymind.net";
    tokenIdFile = "/home/deathraymind/secrets/token_id";
    tokenFile = "/home/deathraymind/secrets/token";
    api.ssl.enable = false;
    # api.ssl.certFile = "/home/deathraymind/secrets/cert";
    # api.ssl.keyFile = "/home/deathraymind/secrets/key";
  };

  # --- SYSTEM BACKENDS & CONFIG ---
  virtualisation.docker.enable = true;
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
