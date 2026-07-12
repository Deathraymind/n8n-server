{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    blueman
  ];
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "blueman-applet"
    ];
    windowrule = lib.mkForce [
      "match:class ^(blueman-manager)$, float on"
      "match:class ^(blueman-manager)$, size 600 400"
      "match:class ^(blueman-manager)$, move 100%-620 60"
      "match:class ^(blueman-manager)$, pin on"
    ];
  };
}
