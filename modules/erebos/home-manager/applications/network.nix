{
  pkgs,
  lib,
  ...
}: {
  # 1. Install the GUI editor
  home.packages = with pkgs; [
    networkmanagerapplet # Provides nm-connection-editor and the tray icon
  ];

  wayland.windowManager.hyprland.settings = {
    # 2. Auto-start the tray applet so you can see your Wi-Fi signal
    exec-once = [
      "nm-applet --indicator"
    ];

    # 3. Modern 2026 Window Rules
    windowrule = lib.mkForce [
      # Float and size the editor
      "match:class ^(nm-connection-editor)$, float on"
      "match:class ^(nm-connection-editor)$, size 600 400"

      # Move to top right (matching your other tools)
      "match:class ^(nm-connection-editor)$, move 100%-620 60"

      "match:class ^(nm-connection-editor)$, pin on"
    ];
  };
}
