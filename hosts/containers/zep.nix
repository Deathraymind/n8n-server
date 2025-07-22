{ config, pkgs, ... }:

{
  # Ensure the persistent data directory for Zep exists and has the right permissions

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      zep = {
        image = "zepai/zep:latest";
        autoStart = true;
        ports = [ "8000:8000" ];
        volumes = [
            "/var/lib/zep:/var/lib/zep"
        ];
        environment = {
          # Add Zep-specific environment variables here if needed
          TZ = "Asia/Tokyo";
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8000 ];  # Allow Zep's main port
  };
}

