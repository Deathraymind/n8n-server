{
  pkgs,
  inputs,
  config,
  lib,
  ollama-fix,
  ...
}: let
  # This tells Nix to use the unstable branch for this specific variable
  unstable = import inputs.nixpkgs-unstable {
    system = "x86_64-linux"; # Standard for most PCs
    config.allowUnfree = true;
  };
in {
  nixpkgs.config.allowUnfree = true;
  hardware.amdgpu.opencl.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics = {
    enable = true;
  };

  services.ollama = {
    enable = true;
    package = ollama-fix;
    acceleration = "rocm";
    rocmOverrideGfx = "10.3.1";
    host = "0.0.0.0"; # listen on all interfaces, not just loopback
    port = 11434;
    openFirewall = true; # opens 11434 in the NixOS firewall
  };
  environment.variables = {
    HSA_OVERRIDE_GFX_VERSION = "10.3.1";
    LD_LIBRARY_PATH = lib.mkForce "/run/opengl-driver/lib";

    # This tells ROCm to be extra vocal about why it might fail
    AMD_LOG_LEVEL = "3";
    ROCR_VISIBLE_DEVICES = "0";
  };
  environment.systemPackages = [ollama-fix];
  # Required for ROCm to work correctly on NixOS
}
