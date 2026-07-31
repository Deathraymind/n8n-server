{pkgs, ...}: {
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium; # This swaps standard chromium for the degoogled version

    # You can safely use standard chromium options here
    extensions = [
      # Example: adding an extension via crx path or webstore helper
      # { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
    ];

    # Declarative command-line flags (e.g., forcing Wayland ozone if not globally set)
    commandLineArgs = [
      "--ozone-platform-hint=auto"
      "--enable-features=WaylandWindowDecorations"
    ];
  };
}
