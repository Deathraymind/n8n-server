{
  config,
  pkgs,
  ...
}: {
  # widevine-cdm is unfree — needed for Netflix/Prime/Spotify DRM.
  # If your nixpkgs isn't already unfree-permissive, uncomment:
  # nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfree = true;

  programs.qutebrowser = {
    enable = true;

    # override the package to bake in the Widevine DRM CDM
    package = pkgs.qutebrowser.override {
      enableWideVine = true; # note the capital V — it's enableWideVine, not enableWidevine
    };

    settings = {
      qt.force_software_rendering = "chromium";
      qt.args = [
      ];
      # --- the minimal chrome ---
      tabs = {
        show = "multiple"; # tab bar only appears when >1 tab open; "never" hides it entirely
        position = "top"; # tab strip location (you switched this from "left" to "top")
      };
      statusbar.show = "in-mode"; # bottom bar only shows in command/insert mode; "always" keeps url+scroll visible
      scrolling.smooth = true;
      auto_save.session = true;
      # dark-ish
      colors.webpage.preferred_color_scheme = "dark"; # tell sites you prefer dark
      colors.webpage.darkmode.enabled = false; # true = force-invert every site (aggressive, breaks some pages)
      # built-in ad/tracker blocking (Brave's ABP lists) — no extension needed
      content.blocking.method = "both"; # adblock lists + hosts file
      downloads.location.directory = "${config.home.homeDirectory}/Downloads";
    };
    searchEngines = {
      DEFAULT = "https://duckduckgo.com/?q={}";
      nix = "https://search.nixos.org/packages?query={}";
      hm = "https://home-manager-options.extranix.com/?query={}";
    };
    keyBindings = {
      normal = {
        ",t" = "config-cycle tabs.show never multiple"; # toggle the tab bar on demand
        ",m" = "spawn mpv {url}"; # hand the current page to mpv (needs mpv + yt-dlp installed)
      };
    };
    loadAutoconfig = false;
  };
}
