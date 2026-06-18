{
  pkgs,
  config,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    # Set up resource limits
    daemon.settings = {
      experimental = true;
      default-address-pools = [
        {
          base = "172.30.0.0/16";
          size = 24;
        }
      ];
    };
  };
  sops.defaultSopsFile = ../../secrets/pelican.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  sops.secrets."pelican/app_key" = {
    owner = "deathraymind";
    group = "nginx";
    mode = "0400";
  };
  config.services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureDatabases = ["mydatabase"];
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
      host  all       all     127.0.0.1/32   trust
      host  all       all     ::1/128        trust
      host    all     all     192.168.1.0/24   md5
    '';
    initialScript = pkgs.writeText "init.sql" ''
      ALTER USER postgres WITH PASSWORD '6255';
    '';
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

  users.users.bowyn = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker"];
  };

  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    docker
    docker-compose
    git
  ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
