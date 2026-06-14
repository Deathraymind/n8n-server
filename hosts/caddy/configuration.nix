{pkgs, ...}: {
  # --- NETWORKING & BOOT ---
  boot.loader.grub.enable = true;
  networking.networkmanager.enable = true;
  systemd.services.systemd-networkd-wait-online.enable = pkgs.lib.mkForce false;
  networking.useDHCP = pkgs.lib.mkDefault true;

  # SWAP THIS: Disable QEMU, Enable XCP-ng Guest tools
  services.qemuGuest.enable = false;
  services.xe-guest-utilities.enable = true;
  boot.growPartition = true;

  # --- REST OF YOUR CONFIG ---
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };

  environment.systemPackages = with pkgs; [git vim curl htop];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
