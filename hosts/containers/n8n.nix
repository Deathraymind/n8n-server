{ config, pkgs, ... }:

{

    # Create the /var/lib/n8n directory with correct perms
  systemd.tmpfiles.rules = [
    "d /var/lib/n8n 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      n8n = {
        image = "n8nio/n8n";
        autoStart = true;
        ports = [ "5678:5678" ];
        volumes = [ "/var/lib/n8n:/home/node/.n8n" ];
        environment = {
         N8N_WEBHOOK_URL = "https://n8n.deathraymind.net/";
         N8N_EDITOR_BASE_URL = "https://n8n.deathraymind.net/";
         GENERIC_TIMEZONE= "Asia/Tokyo";
        };
      };
    };
  };

   networking.firewall = {
    allowedTCPPorts = [ 5678 ]; 
    allowedUDPPorts = [ 5678 ];
    };
}

