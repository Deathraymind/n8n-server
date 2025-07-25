{ config, pkgs, agenix, ... }:

{
  # Install agenix CLI
  environment.systemPackages = with pkgs; [
    agenix.packages.${pkgs.system}.default
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Use agenix for the Cloudflare token

  security.acme = {
    acceptTerms = true;
    defaults.email = "deathraymind@gmail.com";

    certs."deathraymind.net" = {
      group = "caddy";
      domain = "deathraymind.net";
      extraDomainNames = [ "*.deathraymind.net" ];
      dnsProvider = "cloudflare";
      environmentFile = ./../../secrets/cloudflare.env;  
    };
  };

  services.caddy = {
    enable = true;

    virtualHosts."n8n.deathraymind.net".extraConfig = ''
      reverse_proxy http://192.168.1.202:5678

      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';
    virtualHosts."jellyfin.deathraymind.net".extraConfig = ''
      reverse_proxy http://192.168.1.202:8096

      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';

  };
}


