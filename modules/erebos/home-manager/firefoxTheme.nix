{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

  # Dook97's qutebrowser-like userChrome, pinned.
  qutebrowserSrc = pkgs.fetchFromGitHub {
    owner = "Dook97";
    repo = "firefox-qutebrowser-userchrome";
    rev = "b3fced9f6988cbe0f5f5573a7e679d6a3da7b1d8";
    hash = "sha256-eGBHS/IH7C0yvwCa+R3R/XtHjhAeXlnRIsgsc7Mq6B0=";
  };

  userChromeCss =
    builtins.replaceStrings
    ["DejaVu Sans Mono"] ["JetBrainsMono Nerd Font"]
    (builtins.readFile "${qutebrowserSrc}/userChrome.css");

  # ── Colors ────────────────────────────────────────────────
  # Stylix palette for accents/highlights; deep black for the base chrome.
  c = config.lib.stylix.colors;
  black = "#0a0c10";
  activeTab = "#${c.base02}"; # highlighted (selected) tab bg
  accent = "#${c.base0D}"; # active-tab accent stripe
  activeFg = "#${c.base05}"; # selected tab text
  inactiveFg = "#${c.base04}"; # unselected tab text
  urlbarFocus = "#${c.base01}"; # urlbar bg when focused
in {
  programs.firefox = {
    enable = true;
    package = unstable.firefox;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.compactmode.show" = true;
        "browser.uidensity" = 1;
        "browser.nova.enabled" = false;
        "widget.gtk.rounded-bottom-corners.enabled" = false; # square window corners
      };

      userChrome =
        userChromeCss
        + ''

          /* ══ overrides ══════════════════════════════════════ */

          /* Colors — Stylix accents over a deep-black base */
          :root {
            --tab-active-bg-color: ${activeTab};
            --tab-inactive-bg-color: ${black};
            --tab-active-fg-fallback-color: ${activeFg};
            --tab-inactive-fg-fallback-color: ${inactiveFg};
            --urlbar-focused-bg-color: ${urlbarFocus};
            --urlbar-not-focused-bg-color: ${black};
            --toolbar-bgcolor: ${black} !important;
          }

          /* Accent stripe on the selected tab (inset = no layout shift) */
          .tabbrowser-tab[selected] .tab-background {
            box-shadow: inset 0 2px 0 0 ${accent} !important;
          }

          /* Square every corner */
          :root {
            --tab-border-radius: 0 !important;
            --toolbarbutton-border-radius: 0 !important;
            --urlbar-border-radius: 0 !important;
            --toolbar-field-border-radius: 0 !important;
            --arrowpanel-border-radius: 0 !important;
            --panel-border-radius: 0 !important;
          }
          .tab-background,
          .tabbrowser-tab .tab-content,
          #urlbar, #urlbar-background, #searchbar, .urlbarView,
          menupopup, panel, menu, menuitem, menucaption {
            border-radius: 0 !important;
          }

          /* A little frame so nothing's crammed against the edge */
          #navigator-toolbox { padding: 4px 4px 0 !important; }
          .tabbrowser-tab { margin-inline: 1px !important; }
        '';
    };
  };
}
