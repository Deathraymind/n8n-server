{
  description = "NixOS Docker Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, flake-utils, agenix, ... }:
    {
      nixosConfigurations.docker-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/docker-host.nix
          ./hosts/services/postgress/postgress.nix
          /etc/nixos/configuration.nix
          agenix.nixosModules.default
        ];
        specialArgs = { inherit agenix; };
      };
    };
}

