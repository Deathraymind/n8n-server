{pkgs, ...}: {
  imports = [
    ./homepage.nix
  ];

  # --- SYSTEM & NETWORKING CONFIGURATION ---
  networking.hostName = "nix-nas";
  boot.loader.grub.enable = true;
  networking.networkmanager.enable = true;
  systemd.services.systemd-networkd-wait-online.enable = pkgs.lib.mkForce false;
  networking.useDHCP = pkgs.lib.mkDefault true;

  # Firewall Rules
  networking.firewall.allowedTCPPorts = [80 443 3000 8080 8081 8384];

  # Virtualization & Remote Access
  services.qemuGuest.enable = true;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # --- USER CONFIGURATION ---
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel" "nextcloud"];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
  };

  # --- SYSTEM PACKAGES ---
  environment.systemPackages = with pkgs; [
    nextcloud33
  ];

  # --- NEXTCLOUD CONFIGURATION ---
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "0.0.0.0";
    settings = {
      trusted_domains = ["192.168.1.105"];
      files_external_allow_create_steps_local = true;
    };
    config = {
      adminuser = "deathraymind";
      #  echo -n "YourPasswordHere" | sudo tee /etc/nextcloud-admin-pass
      adminpassFile = "/etc/nextcloud-admin-pass";
      dbtype = "sqlite";
    };
  };

  # --- PAIRDROP CONFIGURATION ---
  services.pairdrop = {
    enable = true;
    port = 3000;
  };

  # --- SYNCTHING CONFIGURATION ---
  services.syncthing = {
    enable = true;
    overrideFolders = true;
    guiAddress = "0.0.0.0:8384";
    openDefaultPorts = true;
    user = "nextcloud";
    group = "nextcloud";
    dataDir = "/var/lib/nextcloud/.local/share/syncthing";
    configDir = "/var/lib/nextcloud/.config/syncthing";
    settings.gui = {
      user = "deathraymind";
      # nix-shell -p apacheHttpd --run "htpasswd -B -n deathraymind"
      password = "$2y$05$JD3E5X0/qxKZLDYx4G1ZHOu6Vysq/YT0yPOg34mQjbsglyv2JkJjC";
    };
  };

  # Syncthing Theme Script
  system.activationScripts.syncthing-vellum-theme = let
    vellum-theme-src = ./syncthing-themes;
    targetDir = "/var/lib/nextcloud/.config/syncthing/gui";
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
      chown -R nextcloud:nextcloud "${targetDir}/../"
    '';
  };
}
