{
  description = "NixOS Docker Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    agenix,
    ...
  }: {
    nixosConfigurations.caddy = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/caddy/caddy-host.nix
        ./services/postgress/postgress.nix
        ./hosts/caddy/configuration.nix
        agenix.nixosModules.default
      ];
      specialArgs = {inherit agenix;};
    };
  };
}
