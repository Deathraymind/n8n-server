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
        ./hosts/caddy/hardware-configuration.nix # Include our rewritten hardware file
        agenix.nixosModules.default

        # This block instructs Nix to build a generic VHD image layout
        ({modulesPath, ...}: {
          virtualisation.diskSize = 20480; # 20 GB Image
        })
      ];
      specialArgs = {inherit agenix inputs;};
    };

    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nas/nas-host.nix
        ./hosts/nas/configuration.nix
        agenix.nixosModules.default

        # Proxmox specific configuration (Replaced hardware-configuration.nix)
        ({modulesPath, ...}: {
          virtualisation.diskSize = 20480; # 20 GB initial image size
          services.qemuGuest.enable = true;
          boot.growPartition = true; # Automatically expands to fit Proxmox disk resizes
          networking.hostName = "nix-nas";
          nix.settings.trusted-users = ["root" "deathraymind"];
        })
      ];
      specialArgs = {inherit agenix inputs;};
    };

    nixosConfigurations.pelican = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./hosts/pelican/pelican-host.nix
        ./hosts/pelican/configuration.nix
        agenix.nixosModules.default

        # Proxmox specific configuration (Replaced hardware-configuration.nix)
        ({modulesPath, ...}: {
          imports = [(modulesPath + "/virtualisation/proxmox-image.nix")];
          virtualisation.diskSize = 20480; # 20 GB initial image size
          services.qemuGuest.enable = true;
          boot.growPartition = true; # Automatically expands to fit Proxmox disk resizes
          networking.hostName = "pelican";
          nix.settings.trusted-users = ["root" "deathraymind"];
        })
      ];
      specialArgs = {inherit agenix inputs;};
    };
    nixosConfigurations.pelican-wings = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./hosts/pelican-wings/pelican-wings.nix
        ./hosts/pelican-wings/configuration.nix
        agenix.nixosModules.default

        # Proxmox specific configuration (Replaced hardware-configuration.nix)
        ({modulesPath, ...}: {
          imports = [(modulesPath + "/virtualisation/proxmox-image.nix")];
          virtualisation.diskSize = 20480; # 20 GB initial image size
          services.qemuGuest.enable = true;
          boot.growPartition = true; # Automatically expands to fit Proxmox disk resizes
          networking.hostName = "pelican";
          nix.settings.trusted-users = ["root" "deathraymind"];
        })
      ];
      specialArgs = {inherit agenix inputs;};
    };
  };
}
