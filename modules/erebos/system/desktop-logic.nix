{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.services.xserver.enable || config.programs.hyprland.enable) {
    # 1. Automatic linking for Home Manager apps
    # This triggers if EITHER Xserver or Hyprland is enabled system-wide
    environment.pathsToLink = [
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];

    # 2. Portal Plumbing
    #   xdg.portal = {
    #enable = true;
    #config.common.default = "*";
    #extraPortals = [pkgs.xdg-desktop-portal-hyprland];
    #};

    # 3. Common System requirements for desktop apps
    services.dbus.enable = true;
  };
}
