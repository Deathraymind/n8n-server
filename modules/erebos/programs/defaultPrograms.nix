{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    obsidian
    git
    firefox
    kitty
    xorg.xrdb
    orca-slicer
    gnome-disk-utility
    nautilus
    obs-studio
    python3
    arduino-ide
  ];
}
