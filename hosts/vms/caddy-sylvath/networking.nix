{
  pkgs,
  lib,
  ...
}: {
  # Configure your specific network interface
  networking.interfaces.enp1s0 = {
    ipv4.addresses = [
      {
        address = "10.0.0.150";
        prefixLength = 24;
      }
    ];
  };

  # Set the default gateway

  # Set your DNS servers
  time.timeZone = "Europe/Berlin";
  networking = {
    firewall.allowedTCPPorts = [8080 2022];
    defaultGateway = "10.0.0.1";
    hostName = "caddy";
    nameservers = ["1.1.1.1" "8.8.8.8"];
    networkmanager.enable = true;
    useDHCP = false;
  };

  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  services.openssh = {
    settings.PasswordAuthentication = true;
    enable = true;
  };
}
