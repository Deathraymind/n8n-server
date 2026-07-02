{pkgs, ...}: {
  imports = [
    ./homepage.nix
  ];

  # --- SYSTEM & NETWORKING CONFIGURATION ---
  boot.loader.grub.enable = true;
  networking.networkmanager.enable = true;
  systemd.services.systemd-networkd-wait-online.enable = pkgs.lib.mkForce false;
  networking.useDHCP = pkgs.lib.mkDefault true;
  systemd.tmpfiles.rules = [
    "d /mnt/nas-data  0770 nextcloud nextcloud - -"
    "Z /mnt/nas-data/nextcloud 0770 nextcloud nextcloud - -"
  ];
  fileSystems."/mnt/nas-data" = {
    device = "192.168.1.100:/export/data";
    fsType = "nfs";
    options = ["nfsvers=4.2" "x-systemd.automount" "noauto" "_netdev"];
  };
  # Firewall Rules
  networking.firewall.allowedTCPPorts = [80 443 3000 8080 8081 8384 8443];

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
  virtualisation.docker.enable = true;

  # 2. Define the Vaultwarden container
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      vaultwarden = {
        image = "vaultwarden/server:latest"; # Includes the Web Vault UI
        ports = [
          "8443:80" # Maps local port 8443 to container port 80
        ];
        volumes = [
          "/var/lib/vaultwarden:/data" # Persists your passwords/data on the host
        ];
        environment = {
          # Change this to the external URL your separate Caddy server will use
          DOMAIN = "https://yourdomain.com";
          SIGNUPS_ALLOWED = "true"; # Turn to "false" after creating your account
        };
        autoStart = true;
      };
    };
  };

  # --- NEXTCLOUD CONFIGURATION ---
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "0.0.0.0";
    datadir = "/mnt/nas-data/nextcloud/";
    # datadir = "/mnt/nas-data/nextcloud";
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
    #  sudo mkfs.ext4 -L nas-data /dev/sda
    dataDir = "/var/lib/syncthing";
    configDir = "/var/lib/syncthing/.config";
    settings.gui = {
      user = "deathraymind";
      # nix-shell -p apacheHttpd --run "htpasswd -B -n deathraymind"
      password = "$2y$05$JD3E5X0/qxKZLDYx4G1ZHOu6Vysq/YT0yPOg34mQjbsglyv2JkJjC";
    };

    # Map actual storage out to your ZFS pool share path
    settings.folders = {
      "nas-sync" = {
        path = "/mnt/nas-data/syncthing";
      };
    };
  };

  # Syncthing Theme Script
  system.activationScripts.syncthing-vellum-theme = let
    vellum-theme-src = ./syncthing-themes;
    targetDir = "/var/lib/syncthing/.config/gui";
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

      # 4. Correct ownership of local runtime state directory
      chown -R nextcloud:nextcloud "/var/lib/syncthing"
    '';
  };
}
