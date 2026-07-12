{
  inputs,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    shortcut = "a"; # Changes prefix to Ctrl+a (highly recommended, easier to reach than Ctrl+b)
    baseIndex = 1; # Starts window numbering at 1 instead of 0 (matches your keyboard layout)

    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
      continuum
      better-mouse-mode
      fuzzback
    ];

    extraConfig = ''
                      # --- Pane Navigation (Vim style) ---
                  bind -n M-h select-pane -L
      bind -n M-j select-pane -D
      bind -n M-k select-pane -U
      bind -n M-l select-pane -R                          # Enable mouse support for dragging panes and scrolling (great for beginners!)
                                set -g mouse on
                          bind v split-window -h -c "#{pane_current_path}"
    '';
  };
}
