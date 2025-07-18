{ pkgs, config, ... }:
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme = {
  acceptTerms = true;
  defaults.email = "deathraymind@gmail.com";

  certs."deathraymind.net" = {
    group = config.services.caddy.group;
    domain = "deathraymind.net";
    extraDomainNames = [ "*.deathraymind.net" ];
    dnsProvider = "cloudflare";
    environmentFile = config.age.secrets.cloudflare.path;
  };
};
  services.caddy.virtualHosts."n8n.deathraymind.net".extraConfig = ''
  reverse_proxy http://localhost:5678

  tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/your.domain.com/key.pem {
    protocols tls1.3
  }
'';
}

