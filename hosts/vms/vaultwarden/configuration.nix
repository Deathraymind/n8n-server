{
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [];
  virtualisation.diskSize = lib.mkForce 30480;
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
  services.esphome = {
    enable = true;
    address = "0.0.0.0";
    openFirewall = true;
  };
  # --- CONTAINERS CONFIGURATION ---
  virtualisation.docker.enable = true;
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      vaultwarden = {
        image = "vaultwarden/server:latest";
        ports = ["8443:80"];
        volumes = ["/var/lib/vaultwarden:/data"];
        environment = {
          DOMAIN = "https://vaultwarden.deathraymind.net";
          SIGNUPS_ALLOWED = "true"; # Switch to "false" after setup
        };
        autoStart = true;
      };

      uptimekuma = {
        image = "louislam/uptime-kuma:1";
        ports = ["3001:3001"];
        volumes = ["/var/lib/uptime-kuma:/app/data"];
        autoStart = true;
      };

      adguardhome = {
        image = "adguard/adguardhome:latest";
        ports = [
          "53:53/tcp"
          "53:53/udp" # DNS
          "3000:3000/tcp"
          "80:80/tcp" # Web UI Setup / Dashboard
          "443:443/tcp"
          "853:853/tcp" # Encrypted DNS (Optional)
        ];
        volumes = [
          "/var/lib/adguardhome/work:/opt/adguardhome/work"
          "/var/lib/adguardhome/conf:/opt/adguardhome/conf"
        ];
        autoStart = true;
      };
      homeassistant = {
        image = "ghcr.io/home-assistant/home-assistant:stable";
        volumes = [
          "/var/lib/hass:/config"
          "/run/dbus:/run/dbus:ro" # Bluetooth via host dbus
          "/etc/localtime:/etc/localtime:ro"
        ];
        ports = [
          "5353:5353/tcp"
          "8123:8123/tcp" # Web UI Setup / Dashboard
        ];

        environment = {
          TZ = "Asia/Tokyo";
        };
        extraOptions = [
          "--network=host" # needed for mDNS/SSDP/DHCP device discovery
          # "--device=/dev/ttyUSB0"  # uncomment if you have a Zigbee/Z-Wave stick
        ];
        autoStart = true;
      };
    };
  };

  # --- SYSTEM NETWORKING & STORAGE ---
  networking.firewall = {
    allowedTCPPorts = [53 3000 80 443 853 8123];
    allowedUDPPorts = [53 5353];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/adguardhome/work 0755 root root -"
    "d /var/lib/adguardhome/conf 0755 root root -"
    "d /var/lib/adguardhome/work 0755 root root -"
    "d /var/lib/adguardhome/conf 0755 root root -"
    "d /var/lib/hass 0755 root root -"
  ];
}
