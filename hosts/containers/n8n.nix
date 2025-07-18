{ config, pkgs, ... }:

{

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      n8n = {
        image = "n8nio/n8n";
        autoStart = true;
        ports = [ "5678:5678" ];
        environment = {
          ENV_VAR = "test";
        };
      };
    };
  };

    networking.firewall = {
    allowedTCPPorts = [ 5678 ]; 
    allowedUDPPorts = [ 5678 ];
    };
}

