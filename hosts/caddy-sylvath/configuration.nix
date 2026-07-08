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

  sops.secrets."pelican/cloudflare" = {
    owner = "acme";
    mode = "0400";
  };
  sops.secrets."pelican/cloudflareddns" = {
    owner = "acme";
    mode = "0400";
  };

  services.postgresql = {
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
    domains = ["sylvath.deathraymind.net"];
    proxied = false; # set true if you want the orange cloud
    ipv4 = true;
    ipv6 = false; # enable if your ISP gives you a stable v6 prefix
    frequency = "*:0/5"; # every 5 min; default is fine, this just makes it explicit
    apiTokenFile = config.sops.secrets."pelican/cloudflareddns".path;
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
      extraDomainNames = ["*.deathraymind.net" "*.sylvath.deathraymind.net"];
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets."pelican/cloudflare".path;
    };
  };
  services.caddy = {
    enable = true;

    virtualHosts."wings.sylvath.deathraymind.net".extraConfig = ''
      reverse_proxy http://10.0.0.200:8080
      tls /var/lib/acme/deathraymind.net/fullchain.pem /var/lib/acme/deathraymind.net/key.pem {
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
