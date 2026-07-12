{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.ErebOS.homeNoctalia;
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  options.ErebOS.homeNoctalia = {
    enable = lib.mkEnableOption "ErebOS Noctalia Shell Configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.noctalia-shell = {
      enable = true;
      settings = {
        bar = {
          position = "top";
        };
      };
    };
  };
}
