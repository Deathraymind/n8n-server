{pkgs, ...}: {
  boot.loader.grub.enable = false;
  # --- NETWORKING CONFIGURATION ---
  networking.networkmanager.enable = true;
  systemd.services.systemd-networkd-wait-online.enable = false;
  networking = {
    hostName = "Game-Server"; # Keeps your hostname

    # 1. Disable DHCP so the IP doesn't change automatically
    useDHCP = false;
    interfaces.enp3s0.useDHCP = false; # Replace enp3s0 with your interface

    # 2. Assign your static IP address
    interfaces.enp3s0.ipv4.addresses = [
      {
        address = "192.168.1.135";
        prefixLength = 24; # This matches a standard 255.255.255.0 subnet
      }
    ];

    # 3. Set your Gateway (usually your router's IP)
    defaultGateway = "192.168.1.1";

    # 4. Set DNS servers (using Google and Cloudflare here)
    nameservers = ["1.1.1.1" "8.8.8.8"];
  };
  # --- VIRTUALIZATION & ACCESS ---
  services.qemuGuest.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # --- USER CONFIGURATION ---
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["networkmanager" "wheel"]; # 'wheel' enables sudo

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." # <-- Your public SSH key
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
    app.url = "https://panel.deathraymind.com";
    app.keyFile = "/var/secrets/pelican/app.key";
    database.passwordFile = "/var/secrets/pelican/dbpassword";
    redis.passwordFile = "/var/secrets/pelican/redispassword";
    mail.passwordFile = "/var/secrets/pelican/mailpassword";
  };

  # --- PELICAN WINGS (Cleanly commented out so it doesn't break syntax) ---
  # services.pelican.wings = {
  #   enable = true;
  #   openFirewall = true;
  #   uuid = "your-node-uuid";
  #   remote = "https://panel.deathraymind.com";
  #   tokenIdFile = "/home/deathraymind/secrets/token_id";
  #   tokenFile = "/home/deathraymind/secrets/token";
  #   api.ssl.enable = true;
  #   api.ssl.certFile = "/home/deathraymind/secrets/cert";
  #   api.ssl.keyFile = "/home/deathraymind/secrets/key";
  # };

  # --- SYSTEM BACKENDS & CONFIG ---
  virtualisation.docker.enable = true;
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
