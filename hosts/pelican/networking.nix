{
  pkgs,
  lib,
  ...
}: {
  # Configure your specific network interface
  networking.interfaces.enp1s0 = {
    ipv4.addresses = [
      {
        address = "192.168.1.50";
        prefixLength = 24;
      }
    ];
  };

  # Set the default gateway
  networking = {
    firewall.allowedTCPPorts = [8080 2022 80 443];
    defaultGateway = "192.168.1.1";
    hostName = "pelican";
    nameservers = ["1.1.1.1" "8.8.8.8"];
    networkmanager.enable = true;
    useDHCP = false;
  };
  time.timeZone = "Asia/Tokyo";

  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  services.openssh = {
    settings.PasswordAuthentication = true;
    enable = true;
  };
}
