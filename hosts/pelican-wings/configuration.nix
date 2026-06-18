{
  pkgs,
  lib,
  config,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    # Set up resource limits
    daemon.settings = {
      experimental = true;
      default-address-pools = [
        {
          base = "172.30.0.0/16";
          size = 24;
        }
      ];
    };
  };

  users.users.bowyn = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker"];
  };

  # --- NETWORKING CONFIGURATION ---
  sops.defaultSopsFile = ../../secrets/pelican.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  sops.secrets."pelican/tokenFile" = {
    owner = "pelican-panel";
    group = "nginx";
    mode = "0400";
  };
  sops.secrets."pelican/tokenIdFile" = {
    owner = "pelican-panel";
    group = "nginx";
    mode = "0400";
  };

  # --- VIRTUALIZATION & ACCESS ---
  services.qemuGuest.enable = true;

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
    docker
    docker-compose
    git
  ];

  # --- PELICAN WINGS ---
  services.pelican.wings = {
    enable = true;
    openFirewall = true;
    uuid = "a16a0079-62b6-43d9-b413-3e6ac50d322c";
    remote = "https://panel.deathraymind.net";
    tokenIdFile = config.sops.secrets."pelican/tokenIdFile".path;
    tokenFile = config.sops.secrets."pelican/tokenFile".path;
    api.ssl.enable = false;
  };

  # --- SYSTEM BACKENDS & CONFIG ---
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
