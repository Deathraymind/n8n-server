{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.ErebOS.cachy;
in {
  ### 1. Define the "Switch"
  options.ErebOS.cachy = {
    enable = lib.mkEnableOption "ErebOS Cachy Kernel Configuration";
  };

  ### 2. The Logic
  config = lib.mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackages_cachyos-lto;
    nix.settings = {
      substituters = ["https://chaotic-nyx.cachix.org"];
      trusted-public-keys = ["chaotic-nyx.cachix.org-1:4znLnXGp5i23G/XGzM1M6GfJq5ZgGqyN4/Yj6GZ8R6A="];
    };
  };
}
