{
  pkgs,
  config,
  ...
}: {
  virtualisation.diskSize = 20480; # 20 GB initial image size
  boot.growPartition = true; # Automatically expands to fit Proxmox disk resizes
  fileSystems."/".autoResize = true;
  services.qemuGuest.enable = true;
  # Nix
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "deathraymind"];
  };

  # Virtualisation
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  boot.supportedFilesystems = ["nfs"];
  services.rpcbind.enable = true;
  # Networking

  # SSH
  services.openssh = {
    enable = true;
    settings = {
    };
  };

  # User
  users.users.deathraymind = {
    isNormalUser = true;
    extraGroups = ["wheel" "libvirtd" "kvm"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    virtiofsd
    qemu
    nfs-utils
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
