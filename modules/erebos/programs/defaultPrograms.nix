{
  inputs,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in {
  environment.systemPackages = [
    pkgs.obsidian
    pkgs.git
    pkgs.kitty
    pkgs.xorg.xrdb
    pkgs.orca-slicer
    pkgs.gnome-disk-utility
    pkgs.nautilus
    pkgs.obs-studio
    pkgs.python3
    pkgs.arduino-ide
  ];
}
