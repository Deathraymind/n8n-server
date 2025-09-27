{ config, pkgs, ... }:

{
  time.timeZone = "Asia/Tokyo";
  imports = [
    ./containers/n8n.nix
    ./containers/caddy.nix
    ./containers/jellyfin.nix
    ./containers/homarr.nix


  ];
  services.openssh.enable = true; 
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

  users.users.bowyn = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };

  environment.systemPackages = with pkgs; [
    docker
    docker-compose 
    git
  ];

  networking.firewall.allowedTCPPorts = [ 2375 ]; # Optional: expose Docker API (insecure!)
}

