{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    pavucontrol
  ];

  wayland.windowManager.hyprland.settings = {
    # Modern 2026 syntax: use windowrule with match: prefixes
    # Flags now require an explicit value (on / 1)
    windowrule = lib.mkForce [
      "match:class ^(org.pulseaudio.pavucontrol)$, float on"
      "match:class ^(org.pulseaudio.pavucontrol)$, size 600 400"
      "match:class ^(org.pulseaudio.pavucontrol)$, move 100%-620 60"
      "match:class ^(org.pulseaudio.pavucontrol)$, pin on"
    ];
  };
}
