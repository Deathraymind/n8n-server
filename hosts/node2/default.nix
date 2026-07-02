{
  modulesPath,
  pkgs,
  ...
}: {
  imports = [../../modules/common.nix ./hardware.nix];
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  networking.hostName = "node2";
  networking.bridges.br0.interfaces = ["eno1"];
  virtualisation.libvirtd.allowedBridges = ["br0" "virbr0"];
  networking.interfaces.br0.ipv4.addresses = [
    {
      address = "192.168.1.200";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  # Disable DHCP on eno1 since br0 takes over

  services.openssh.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["root" "deathraymind"];

  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel" "qemu" "libvirtd" "kvm"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };

  system.stateVersion = "25.05";
}
