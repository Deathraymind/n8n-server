{
  description = "NixOS Docker Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    pelican.url = "github:Hythera/nix-pelican";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    agenix,
    ...
  } @ inputs: {
    nixosConfigurations.caddy = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/caddy/caddy-host.nix
        ./services/postgress/postgress.nix
        ./hosts/caddy/configuration.nix
        ./hosts/pelican/hardware-configuration.nix
        agenix.nixosModules.default
      ];
      specialArgs = {inherit agenix;};
    };
    nixosConfigurations.pelican = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./hosts/pelican/pelican-host.nix
        ./hosts/pelican/hardware-configuration.nix
        ./hosts/pelican/configuration.nix
        agenix.nixosModules.default
      ];
      specialArgs = {inherit agenix;};
    };
  };
}
