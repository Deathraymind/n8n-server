{
  inputs,
  pkgs,
  lib,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

  # Dook97's qutebrowser-like userChrome, pinned to a commit.
  qutebrowserSrc = pkgs.fetchFromGitHub {
    owner = "Dook97";
    repo = "firefox-qutebrowser-userchrome";
    rev = "b3fced9f6988cbe0f5f5573a7e679d6a3da7b1d8";
    hash = "sha256-eGBHS/IH7C0yvwCa+R3R/XtHjhAeXlnRIsgsc7Mq6B0="; # ← first rebuild fails and prints the real hash; paste it here
  };

  # Swap the theme's urlbar/tab font to the one you already have installed.
  userChromeCss =
    builtins.replaceStrings
    ["DejaVu Sans Mono"] ["JetBrainsMono Nerd Font"]
    (builtins.readFile "${qutebrowserSrc}/userChrome.css");
in {
  programs.firefox = {
    enable = true;
    package = unstable.firefox; # the build that fixed the popups

    profiles.default = {
      id = 0;
      isDefault = true;

      # Prefs the theme's README requires
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.compactmode.show" = true;
        "browser.uidensity" = 1; # compact
        "browser.nova.enabled" = false;
      };

      userChrome =
        userChromeCss
        + ''

          /* ── my overrides ── */

          /* Breathing room between window border and tabs */
          #navigator-toolbox { padding-top: 0px !important; }

          /* ── Square everything ── */
          :root {
            --tab-border-radius: 0 !important;
            --toolbarbutton-border-radius: 0 !important;
            --urlbar-border-radius: 0 !important;
            --arrowpanel-border-radius: 0 !important;
            --arrowpanel-menuitem-border-radius: 0 !important;
            --toolbar-field-border-radius: 0 !important;
            --identity-box-border-radius: 0 !important;
            --panel-border-radius: 0 !important;
          }

          /* Tabs — the shape you actually see */
          .tab-background,
          .tabbrowser-tab .tab-content { border-radius: 0 !important; }

          /* URL/search field + its results dropdown */
          #urlbar,
          #urlbar-background,
          #searchbar { border-radius: 0 !important; }
          .urlbarView { border-radius: 0 !important; }

          /* Toolbar buttons + their hover highlight */
          .toolbarbutton-1 > .toolbarbutton-icon,
          .toolbarbutton-1 > .toolbarbutton-badge-stack,
          toolbarbutton .toolbarbutton-icon { border-radius: 0 !important; }

          /* Right-click / popup menus and their items */
          menupopup, panel,
          menu, menuitem, menucaption { border-radius: 0 !important; }
        '';
    };
  };
}
