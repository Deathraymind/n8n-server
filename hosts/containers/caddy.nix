{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Secure secret with agenix
  age.secrets.cloudflare.file = ../../secrets/cloudflare.age;

  security.acme = {
    acceptTerms = true;
    defaults.email = "deathraymind@gmail.com";

    certs."deathraymind.net" = {
      group = "caddy"; # Use fixed group to avoid race condition
      domain = "deathraymind.net";
      extraDomainNames = [ "*.deathraymind.net" ];
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets.cloudflare.path;
    };
  };

  services.caddy = {
    enable = true;

    virtualHosts."n8n.deathraymind.net".extraConfig = ''
      reverse_proxy http://localhost:5678

      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';
  };
}


