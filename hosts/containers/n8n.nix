{ config, pkgs, ... }:

{
    virtualisation.oci-containers = {
        backend = "docker";
        containers = {
            n8n = {
                image = "n8nio/n8n";
                autoStart = true;
                ports = [ "5678:5678" ];
                volumes = [
                    "n8n_data:/home/node/.n8n"
                ];
            environment = {
                ENV_VAR = "value";
            };
        extraOptions = [ "--restart=always" ];
            };
        };
    };
}
