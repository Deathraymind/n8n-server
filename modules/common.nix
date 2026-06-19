{
  pkgs,
  config,
  ...
}: {
  virtualisation.diskSize = 20480; # 20 GB initial image size
  boot.growPartition = true; # Automatically expands to fit Proxmox disk resizes

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
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    virtiofsd
    qemu
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
