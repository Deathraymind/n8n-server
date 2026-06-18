{
  config,
  pkgs,
  ...
}: {
  sops.defaultSopsFile = ../../secrets/pelican.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  sops.secrets."pelican/app_key" = {
    owner = "deathraymind";
    group = "nginx";
    mode = "0400";
  };

  services.cloudflare-dyndns = {
    enable = true;

    # Domains or subdomains you want to keep updated with your public IP
    domains = [
      "deathraymind.net"
    ];

    # Points to your existing secret file that contains CLOUDFLARE_API_TOKEN
    apiTokenFile = config.sops.secrets."pelican/app_key".path;
  };

  # Install agenix CLI
  # 1. Enable Cloud-Init so it listens to Proxmox
  # 2. Prevent ACME from racing ahead before Cloud-Init finishes writing the file
  networking.firewall.allowedTCPPorts = [80 443];

  security.acme = {
    acceptTerms = true;
    defaults.email = "deathraymind@gmail.com";

    certs."deathraymind.net" = {
      group = "caddy";
      domain = "deathraymind.net";
      extraDomainNames = ["*.deathraymind.net"];
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets."pelican/app_key".path;
    };
  };
  services.caddy = {
    enable = true;

    virtualHosts."n8n.deathraymind.net" = {
      useACMEHost = "deathraymind.net"; # This automatically configures permissions and links the certs!
      extraConfig = ''
        reverse_proxy http://192.168.1.203:5678
      '';
    };

    virtualHosts."jellyfin.deathraymind.net" = {
      useACMEHost = "deathraymind.net";
      extraConfig = ''
        reverse_proxy http://192.168.1.203:8096
      '';
    };

    virtualHosts."vaultwarden.deathraymind.net" = {
      useACMEHost = "deathraymind.net";
      extraConfig = ''
        # Point Caddy directly to your Nix-Nas IP and Vaultwarden port
        reverse_proxy http://192.168.1.105:8443

        # Tell Caddy to use the certificate files managed by your NixOS ACME configuration
      '';
    };
    virtualHosts."panel.deathraymind.net" = {
      useACMEHost = "deathraymind.net";
      extraConfig = ''
        reverse_proxy http://192.168.1.135:80
      '';
    };

    virtualHosts."node1.deathraymind.net".extraConfig = ''
      # Proxy to the new Wings VM on port 8080
      reverse_proxy http://192.168.1.136:8080

      # Use your existing working wildcard certificates
      tls /var/lib/acme/deathraymind.net/cert.pem /var/lib/acme/deathraymind.net/key.pem {
        protocols tls1.3
      }
    '';
  };
}
