{
  description = "NixOS Docker Host";
  inputs = {
    # Common
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # IshikoriOS
    flake-utils.url = "github:numtide/flake-utils";
    pelican.url = "github:Hythera/nix-pelican";
    sops-nix.url = "github:Mic92/sops-nix";
    #ErebOS
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable"; # for cachy kernal
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    stylix = {
      url = "github:danth/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf-custom.url = "github:deathraymind/nvf";
    niri.url = "github:sodiboo/niri-flake";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    chaotic,
    noctalia,
    nixpkgs-unstable,
    ...
  } @ inputs: let
    # 1. Define the ROCm-specific unstable package here
    system = "x86_64-linux";
    unstable-pkgs = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    # Specifically grab the ROCm-precompiled version
    ollama-unstable-rocm = unstable-pkgs.ollama-rocm;
  in {
    # =============================
    # PHYSICAL NODES
    # =============================
    nixosConfigurations.node-sylvath = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nodes/node-sylvath/default.nix
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.node1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nodes/node1/default.nix
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.node2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nodes/node2/default.nix
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
        ./hosts/vms/caddy/configuration.nix
        ./hosts/vms/caddy/networking.nix
        ./modules/vms/hardware-configuration.nix # Include our rewritten hardware file
        ./modules/common/common.nix # Include our rewritten hardware file

        inputs.sops-nix.nixosModules.sops
        # This block instructs Nix to build a generic VHD image layout
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.caddy-sylvath = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/vms/caddy-sylvath/configuration.nix
        ./hosts/vms/caddy-sylvath/networking.nix
        ./modules/vms/hardware-configuration.nix # Include our rewritten hardware file
        ./modules/common/common.nix # Include our rewritten hardware file

        inputs.sops-nix.nixosModules.sops
        # This block instructs Nix to build a generic VHD image layout
      ];
      specialArgs = {inherit inputs;};
    };

    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/vms/nas/nas-host.nix
        ./hosts/vms/nas/configuration.nix
        ./hosts/vms/nas/networking.nix
        ./modules/vms/hardware-configuration.nix
        ./modules/common/common.nix

        inputs.sops-nix.nixosModules.sops
        # Proxmox specific configuration (Replaced hardware-configuration.nix)
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.vaultwarden = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/vms/vaultwarden/configuration.nix
        ./hosts/vms/vaultwarden/networking.nix
        ./modules/vms/hardware-configuration.nix
        ./modules/common/common.nix

        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {inherit inputs;};
    };
    nixosConfigurations.pelican = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.pelican.nixosModules.default
        {nixpkgs.overlays = [inputs.pelican.overlays.default];}
        ./hosts/vms/pelican/configuration.nix
        ./hosts/vms/pelican/networking.nix
        ./modules/vms/hardware-configuration.nix # Include our rewritten hardware file
        ./modules/common/common.nix # Include our rewritten hardware file
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
        ./modules/vms/hardware-configuration.nix
        ./modules/common/common.nix
        ./hosts/vms/pelican-wings/configuration.nix
        ./hosts/vms/pelican-wings/networking.nix
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
        ./modules/vms/hardware-configuration.nix
        ./modules/common/common.nix
        ./hosts/vms/pelican-sylvath-wings/configuration.nix
        ./hosts/vms/pelican-sylvath-wings/networking.nix
        inputs.sops-nix.nixosModules.sops
        # Proxmox specific configuration (Replaced hardware-configuration.nix)
      ];
      specialArgs = {inherit inputs;};
    };
    # =============================
    # WORKSTATIONS (ErebOS)
    # =============================
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        ollama-fix = ollama-unstable-rocm;
      };
      modules = [
        ./hosts/workstations/desktop/configuration.nix
        ./modules/erebos/system/default.nix
        ./modules/erebos/programs/defaultPrograms.nix
        inputs.home-manager.nixosModules.default
        inputs.stylix.nixosModules.stylix
        chaotic.nixosModules.default
        {
          home-manager = {
            extraSpecialArgs = {inherit inputs;};
            users.deathraymind.imports = [./hosts/workstations/desktop/home.nix];
          };
        }
      ];
    };
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        ollama-fix = ollama-unstable-rocm;
      };
      modules = [
        ./hosts/workstations/laptop/configuration.nix
        ./modules/erebos/system/default.nix
        ./modules/erebos/programs/defaultPrograms.nix
        inputs.home-manager.nixosModules.default
        inputs.stylix.nixosModules.stylix
        chaotic.nixosModules.default
        {
          home-manager = {
            extraSpecialArgs = {inherit inputs;};
            users.deathraymind.imports = [./hosts/workstations/laptop/home.nix];
          };
        }
      ];
    };
  };
}
