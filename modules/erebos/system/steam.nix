# homeStylix.nix
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.ErebOS.steam;
in {
  imports = [
  ];

  ### 1. Define the "Switch"
  options.ErebOS.steam = {
    enable = lib.mkEnableOption "ErebOS steam Configuration";
  };
  ### 2. The Logic
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.adwsteamgtk
      pkgs.prismlauncher
      pkgs.unityhub
      pkgs.protonup-qt
    ];
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "steam"
        "steam-unwrapped"
        "unityhub"
        "corefonts"
      ];
    hardware.steam-hardware.enable = true;
    programs.steam = {
      enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
