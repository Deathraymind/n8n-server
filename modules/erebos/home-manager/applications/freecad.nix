#freecad.nix
{pkgs, ...}: {
  # In your home.nix
  home.packages = with pkgs; [
    freecad
    # Use freecad-wayland if you are on a Wayland-based compositor like Sway or Hyprland
  ];
}
