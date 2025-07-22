{ config, pkgs, ... }:

{
  # Ensure the persistent data directory for Zep exists and has the right permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/zep 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      zep = {
        image = "zepai/zep:latest";
        autoStart = true;
        ports = [ "8000:8000" ];
        volumes = [
          "/var/lib/zep:/app/data"            # Persist Zep data and embeddings
          "/etc/zep.yaml:/app/zep.yaml"       # (Optional) Mount your config file
        ];
        environment = {
          # Add Zep-specific environment variables here if needed
          ZEP_CONFIG_FILE = "/app/zep.yaml";
          TZ = "Asia/Tokyo";
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8000 ];  # Allow Zep's main port
  };
}

