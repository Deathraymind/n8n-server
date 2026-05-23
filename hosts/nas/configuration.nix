{pkgs, ...}: {
  networking.hostName = "nix-nas";
  # --- NETWORKING CONFIGURATION ---
  boot.loader.grub.enable = true;
  networking.networkmanager.enable = true;
  systemd.services.systemd-networkd-wait-online.enable = pkgs.lib.mkForce false;

  # Optional: You can explicitly trust DHCP settings globally
  networking.useDHCP = pkgs.lib.mkDefault true;
  # Enable Proxmox Guest Agent so the Proxmox UI can see the VM's IP address
  services.qemuGuest.enable = true;
  # Enable SSH service
  networking.firewall.allowedTCPPorts = [8080 8384];
  services.openssh.enable = true;
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com" # <-- Your public SSH key
    ];

    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };

  # --- FILEBROWSER CONFIGURATION ---
  services.filebrowser = {
    enable = true;
    user = "deathraymind"; # <-- Lifted out of settings so NixOS reads it
    group = "users";
    settings = {
      address = "0.0.0.0";
      dataDir = "/var/lib/filebrowser"; # <-- Keeps systemd happy during boot CHDIR
      port = 8080;
      package = pkgs.filebrowser-quantum;
      root = "/home/deathraymind/Storage"; # Your main NAS data pool
      database = "/var/lib/filebrowser/filebrowser.db"; # Safe global spot for the DB file
    };
  };

  # --- SYNCTHING CONFIGURATION ---
  services.syncthing = {
    enable = true;
    guiAddress = "0.0.0.0:8384";
    openDefaultPorts = true;
    user = "deathraymind";
    dataDir = "/home/deathraymind/.local/share/syncthing";
    configDir = "/home/deathraymind/.config/syncthing";
  };
  # journalctl -u filebrowser.service | grep 'admin' run this to get the password

  # --- AUTOMATIC DIRECTORY, PERMISSIONS, & THEME SETUP ---
  systemd.tmpfiles.rules = [
    "d /var/lib/filebrowser 0750 deathraymind users - -"
    "d /var/lib/filebrowser/branding 0755 deathraymind users - -"
    "d /home/deathraymind/Storage 0755 deathraymind users - -"

    # Declaratively downloads the theme file from GitHub and puts it exactly where FileBrowser needs it
    "L+ /var/lib/filebrowser/branding/custom.css - - - - ${./filebrowser-theme.css}"
  ];
  # --- SYNCTHING VELLUM THEME ---
  system.activationScripts.syncthing-vellum-theme = let
    # Points directly to the local folder in your flake repository
    vellum-theme-src = ./syncthing-themes;
    targetDir = "/home/deathraymind/.config/syncthing/gui";
  in {
    text = ''
      # 1. Purge old links
      rm -rf "${targetDir}/vellum-light" "${targetDir}/vellum-dark"

      # 2. Make clean parent directories
      mkdir -p "${targetDir}/vellum-light"
      mkdir -p "${targetDir}/vellum-dark"

      # 3. Symlink the assets from the local flake storage (via the Nix store)
      ln -sfn "${vellum-theme-src}/vellum-light/assets" "${targetDir}/vellum-light/assets"
      ln -sfn "${vellum-theme-src}/vellum-dark/assets" "${targetDir}/vellum-dark/assets"

      # 4. Correct ownership
      chown -R deathraymind:users "${targetDir}/../"
    '';
  };

  services.openssh.settings.PasswordAuthentication = true;
  # System packages
  environment.systemPackages = with pkgs; [
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
