{pkgs, ...}: {
  networking.hostName = "caddy-vm";
  # --- NETWORKING CONFIGURATION ---
  # Enable NetworkManager to handle DHCP for IPv4 and IPv6 automatically
  networking.networkmanager.enable = true;

  # Optional: You can explicitly trust DHCP settings globally
  networking.useDHCP = pkgs.lib.mkDefault true;
  # Enable Proxmox Guest Agent so the Proxmox UI can see the VM's IP address
  services.qemuGuest.enable = true;
  # Enable SSH service
  services.openssh.enable = true;

  # Define your user and inject your SSH public key for instant access
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["networkmanager" "wheel"]; # 'wheel' enables sudo

    # Put your SSH key here so you can log in without a password
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." # <-- Your public SSH key
    ];

    # 2. Set an initial password (hashed for security)
    # This sets the password to "password123" as an example.
    # You can generate your own hash by running: mkpasswd -m sha-512
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };
  services.openssh.settings.PasswordAuthentication = true;
  # System packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
  ];
  services.pelican.panel = {
    enable = true;
    app.url = "https://panel.example.com";
    app.keyFile = "/path/to/app.key"; # Generate with: openssl rand -base64 32
    database.passwordFile = "/path/to/db/password";
    redis.passwordFile = "/path/to/redis/password";
    mail.passwordFile = "/path/to/mail/password";
  };

  # 2. The Backend (Wings)
  services.pelican.wings = {
    enable = true;
    openFirewall = true;
    uuid = "your-node-uuid";
    remote = "https://panel.example.com";
    tokenIdFile = "/path/to/token/id";
    tokenFile = "/path/to/token";
    api.ssl.enable = true;
    api.ssl.certFile = "/path/to/cert";
    api.ssl.keyFile = "/path/to/key";
  };

  # 3. Enable Docker (Required for Wings)
  virtualisation.docker.enable = true;

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
