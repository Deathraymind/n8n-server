# gwfox.nix — GWFox (macOS-inspired Firefox skin) applied declaratively via home-manager.
#
# What this does, mechanically:
#   - Fetches the two theme files (userChrome.css / userContent.css) from the repo.
#   - Feeds them into home-manager's firefox module, which drops them into
#     <profile>/chrome/ for you (the manual "move files into chrome/" step from the README).
#   - Sets the required about:config prefs, plus exposes gwfox's own gwfox.* toggles.
#
# The theme is fully self-contained: every url() in the CSS points at Firefox's
# internal chrome:// icons, so there are no image assets to vendor.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # ── Which Firefox profile to skin ─────────────────────────────────────────
  profile = "default"; # ← match the profile name in your programs.firefox.profiles

  # ── Theme source ──────────────────────────────────────────────────────────
  # Option (b): plain fetchFromGitHub. Works with or without flakes.
  # First `nixos-rebuild`/`home-manager switch` will fail with the real hash:
  #   error: hash mismatch ... got: sha256-XXXX
  # Paste that value over lib.fakeHash and rebuild.
  gwfox = pkgs.fetchFromGitHub {
    owner = "akkva";
    repo = "gwfox";
    rev = "072e6f2b023c6ea79bdd7ca89d7ad5aae070e964"; # main @ 2026-07-27
    hash = "sha256-G5gxsRE2QJKybSL7K/xhDP8H2Ko1yA93tm+aU3V3520=";
  };
  #
  # Option (a), recommended for a flake repo like erebos — no hash to babysit,
  # flake.lock pins it and `nix flake update` bumps it:
  #
  #   # flake.nix
  #   inputs.gwfox = { url = "github:akkva/gwfox"; flake = false; };
  #
  # then pass inputs through (extraSpecialArgs) and replace the block above with:
  #   gwfox = inputs.gwfox;

  # ── Preferences ───────────────────────────────────────────────────────────
  gwfoxSettings =
    {
      # Required by the theme (README "Installation").
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      "svg.context-properties.content.enabled" = true;
      "browser.newtabpage.activity-stream.nova.enabled" = false;

      # CJK/IME — README requires this for East Asian input. It's the Firefox Labs
      # "Address Bar: show results during IME composition" toggle. Relevant to you;
      # if a Firefox update renames the key, confirm via about:config modified prefs.
      "browser.urlbar.keepPanelOpenDuringImeComposition" = true;

      # ── gwfox.* customization toggles (README "Customization") ───────────────
      # These are opt-in UI tweaks the theme reads. Flip to taste.
      "gwfox.icons" = true; # menu icons
      "gwfox.blur" = true; # UI blur effects (disable if you see perf issues)
      "gwfox.toolbar" = true; # auto-hide bookmarks toolbar
      # "gwfox.urlbar"   = true;  # move address bar into the (expanded) sidebar
      # "gwfox.atbc"     = true;  # Adaptive Tab Bar Colour compatibility
      # "gwfox.newtab"   = true;  # New Tab transparency (needs allow_transparent_browser)
      "gwfox.noborder" = true; # remove window borders
      # "gwfox.bms"      = true;  # main-window transparency — Linux only, wants a compositor
      # "gwfox.db"       = true;  # disable menu blur
      # "gwfox.ac"       = true;  # accent color (edit --bg0 in userChrome.css)
      "gwfox.sidebar" = 2; # sidebar width: 1 | 2 | 3
    }
    # ── Platform-conditional prefs ──────────────────────────────────────────────
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      "widget.gtk.rounded-bottom-corners.enabled" = true;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      "widget.macos.native-context-menus" = false;
    };
  # Windows (kept for reference; harmless no-ops elsewhere but scoped out on purpose):
  #   "widget.windows.mica"                   = true;
  #   "widget.windows.mica.toplevel-backdrop" = 2;
in {
  # Assumes firefox is managed here. mkDefault so it won't fight an enable set elsewhere.
  programs.firefox.enable = lib.mkDefault true;

  programs.firefox.profiles.${profile} = {
    settings = gwfoxSettings;
    userChrome = builtins.readFile "${gwfox}/userChrome.css";
    userContent = builtins.readFile "${gwfox}/userContent.css";
  };
}
