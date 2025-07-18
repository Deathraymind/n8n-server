{
  description = "NixOS Docker Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    {
      nixosConfigurations.docker-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/docker-host.nix
          /etc/nixos/configuration.nix
        ];
      };
    };
}

