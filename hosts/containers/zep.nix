{ config, pkgs, ... }:

{
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
          "/var/lib/zep:/var/lib/zep"
        ];
        environment = {
          TZ = "Asia/Tokyo";
          ZEP_API_SECRET = "changeme";  # Set this to something secure!
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 8000 ];
  };
}

