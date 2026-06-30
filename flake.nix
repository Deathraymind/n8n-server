{
  description = "NixOS Docker Host";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
    pelican.url = "github:Hythera/nix-pelican";
    sops-nix.url = "github:Mic92/sops-nix";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: {
    # =============================
    # PHYSICAL NODES
    # =============================
    nixosConfigurations.node-sylvath = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/node-sylvath/default.nix
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.node1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/node1/default.nix
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.node2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/node2/default.nix
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {inherit inputs;};
    };
    # =============================
    # VM IMAGES (for building/importing)
    # =============================
    nixosConfigurations.caddy = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/caddy/configuration.nix
        ./hosts/caddy/networking.nix
        ./modules/hardware-configuration.nix # Include our rewritten hardware file
        ./modules/common.nix # Include our rewritten hardware file

        inputs.sops-nix.nixosModules.sops
        # This block instructs Nix to build a generic VHD image layout
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.caddy-sylvath = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/caddy-sylvath/configuration.nix
        ./hosts/caddy-sylvath/networking.nix
        ./modules/hardware-configuration.nix # Include our rewritten hardware file
        ./modules/common.nix # Include our rewritten hardware file

        inputs.sops-nix.nixosModules.sops
        # This block instructs Nix to build a generic VHD image layout
      ];
      specialArgs = {inherit inputs;};
    };

    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nas/nas-host.nix
        ./hosts/nas/configuration.nix
        ./hosts/nas/networking.nix
        ./modules/hardware-configuration.nix
        ./modules/common.nix

        inputs.sops-nix.nixosModules.sops
        # Proxmox specific configuration (Replaced hardware-configuration.nix)
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.pelican = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./hosts/pelican/configuration.nix
        ./hosts/pelican/networking.nix
        ./modules/hardware-configuration.nix # Include our rewritten hardware file
        ./modules/common.nix # Include our rewritten hardware file
        inputs.sops-nix.nixosModules.sops
        # Proxmox specific configuration (Replaced hardware-configuration.nix)
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.pelican-wings = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./modules/hardware-configuration.nix
        ./modules/common.nix
        ./hosts/pelican-wings/configuration.nix
        ./hosts/pelican-wings/networking.nix
        inputs.sops-nix.nixosModules.sops
        # Proxmox specific configuration (Replaced hardware-configuration.nix)
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.pelican-sylvath-wings = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./modules/hardware-configuration.nix
        ./modules/common.nix
        ./hosts/pelican-sylvath-wings/configuration.nix
        ./hosts/pelican-sylvath-wings/networking.nix
        inputs.sops-nix.nixosModules.sops
        # Proxmox specific configuration (Replaced hardware-configuration.nix)
      ];
      specialArgs = {inherit inputs;};
    };
  };
}
