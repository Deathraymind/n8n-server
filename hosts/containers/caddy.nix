{ config, pkgs, lib, ... }:

{
  imports = [
    (builtins.fetchTarball {
      url = "https://github.com/ryantm/agenix/archive/refs/tags/v0.14.0.tar.gz";
    } + "/modules/age.nix")
  ];

  environment.systemPackages = with pkgs; [
    (pkgs.callPackage (builtins.fetchTarball {
      url = "https://github.com/ryantm/agenix/archive/refs/tags/v0.14.0.tar.gz";
    }) { })
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  age.secrets.cloudflare.file = ../../secrets/cloudflare.age;

  security.acme = {
    acceptTerms = true;
    defaults.email = "deathraymind@gmail.com";

    certs."deathraymind.net" = {
      group = "caddy";
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

