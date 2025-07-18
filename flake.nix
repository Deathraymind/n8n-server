{
  description = "NixOS Docker Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
  };

 outputs = { self, nixpkgs, flake-utils, agenix, ... }: {
  nixosConfigurations.docker-host = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./hosts/docker-host.nix
      ./hosts/containers/caddy.nix

      # 👇 Proper flake-based agenix import
      agenix.nixosModules.default
    ];
    specialArgs = { inherit agenix; }; # Optional, if you want to pass agenix to modules
  };
};
} 
