{ config, pkgs, ... }:

{

  systemd.tmpfiles.rules = [
    "d /var/lib/homarr/appdata 0755 1000 1000 - -"
  ];

 virtualisation.oci-containers = {
  backend = "docker";
  containers.homarr = {
    image = "ghcr.io/homarr-labs/homarr:latest";        # or pin a version/digest
    autoStart = true;
    ports = [ "7575:7575" ];
    volumes = [ "/var/lib/homarr/appdata:/appdata" ];
    extraOptions = [ "--pull=always" ]; # re-pull on restart
    environment = {
      GENERIC_TIMEZONE = "Asia/Tokyo";
      SECRET_ENCRYPTION_KEY= "0ba047cac10f692396f5d15e76958bb84a6ca240fd686bb9ff1de87b6f6a130f";
      # optional: TZ = "Asia/Tokyo";
    };
  };
}; 
   networking.firewall = {
    allowedTCPPorts = [ 7575 ]; 
    allowedUDPPorts = [ 7575 ];
    };
}
