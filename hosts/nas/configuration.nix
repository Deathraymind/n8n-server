{pkgs, ...}: {
  networking.hostName = "nix-nas";
  # --- NETWORKING CONFIGURATION ---
  boot.loader.grub.enable = true;
  # Enable NetworkManager to handle DHCP for IPv4 and IPv6 automatically
  networking.networkmanager.enable = true;
  systemd.services.systemd-networkd-wait-online.enable = pkgs.lib.mkForce false;

  # Optional: You can explicitly trust DHCP settings globally
  networking.useDHCP = pkgs.lib.mkDefault true;
  # Enable Proxmox Guest Agent so the Proxmox UI can see the VM's IP address
  services.qemuGuest.enable = true;
  # Enable SSH service
  services.openssh.enable = true;
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel"]; # 'wheel' enables sudo

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com" # <-- Your public SSH key
    ];

    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };
  services.filebrowser = {
    enable = true;
    # Address to bind the server to
    address = "127.0.0.1";
    port = 8080;
    # The directory you want FileBrowser to manage
    root = "/var/lib/filebrowser";
    # Point to your configuration file for more advanced features
    config = /etc/filebrowser/config.yaml;
    passwordFile = "/var/lib/filebrowser/auth.passwd";
  };
  # journalctl -u filebrowser.service | grep 'random password' run this to get the password
  # 1. Create the folder structure
  #sudo mkdir -p /var/lib/filebrowser/

  # 2. Generate and write the hash directly (no touch needed)
  #mkpasswd -m bcrypt "YOUR_SECRET_PASSWORD" | sudo tee /var/lib/filebrowser/auth.passwd

  # 3. Restrict permissions so only root can read it
  # sudo chmod 600 /var/lib/filebrowser/auth.passwd

  # Define your user and inject your SSH public key for instant access
  services.openssh.settings.PasswordAuthentication = true;
  # System packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
