# homeStylix.nix
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  services.twingate.enable = true;
  # Enable libvirtd daemon
  virtualisation.libvirtd.enable = true;
  #  services.expressvpn.enable = true;
  # Install virt-manager
  programs.virt-manager.enable = true;
  programs.kdeconnect = {
    enable = true;
    package = pkgs.valent;
  };
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  xdg.portal = {
    enable = true;
    # Niri officially supports xdg-desktop-portal-gnome for screencasting
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common.default = ["gnome" "gtk"];
      # You can be specific for screencasting if needed:
      # "org.freedesktop.impl.portal.ScreenCast" = "gnome";
    };
  };
  services.flatpak.enable = true;
  nixpkgs.config.allowUnfree = true;
  ### 2. The Logic
  environment.systemPackages = [
    # pkgs.expressvpn
    pkgs.ferium
    pkgs.android-tools
    pkgs.virt-manager
    pkgs.qemu
    pkgs.libvirt
    pkgs.ffmpeg-full
    pkgs.yazi
    pkgs.devbox
    pkgs.nodejs
    pkgs.vesktop
    pkgs.vscode
  ];
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
    ];
}
