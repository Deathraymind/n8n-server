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
      reverse_proxy http://192.168.1.203:5678

      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';
    virtualHosts."jellyfin.deathraymind.net".extraConfig = ''
      reverse_proxy http://192.168.1.203:8096

      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';
    virtualHosts."homarr.deathraymind.net".extraConfig = ''
      reverse_proxy http://192.168.1.203:7575

      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';
    virtualHosts."panel.deathraymind.net".extraConfig = ''
  # WebSocket proxy to Wings node
  reverse_proxy /api/servers/* http://192.168.1.135:8080 {
      transport http {
          versions h2c 1.1
      }
  }

  # Panel frontend
  reverse_proxy / http://192.168.1.135:80 {
      transport http {
          versions h2c 1.1
      }
  }

  tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
      protocols tls1.3
  }
'';

    virtualHosts."nodejp.deathraymind.net".extraConfig = ''
      reverse_proxy http://192.168.1.135:8080
      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }


    '';



  };
}


