{
  inputs,
  pkgs,
  ...
}: {
  programs.zellij = {
    enable = true;

    # Auto-start integration (set to false if you prefer launching manually)
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;

    # Converts this attribute set into ~/.config/zellij/config.kdl
    settings = {
      default_layout = "compact";
      pane_frames = false;

      # Example of setting UI options
      ui = {
        pane_frames = {
          rounded_corners = true;
        };
      };
    };
  };
}
