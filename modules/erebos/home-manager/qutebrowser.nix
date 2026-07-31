{
  config,
  pkgs,
  ...
}: {
  programs.qutebrowser = {
    enable = true;

    settings = {
      # --- the minimal chrome ---
      tabs = {
        show = "multiple"; # tab bar only appears when >1 tab open; "never" hides it entirely
        position = "left"; # when shown, stack them vertically on the side
      };
      statusbar.show = "in-mode"; # bottom bar only shows in command/insert mode; "always" keeps url+scroll visible

      scrolling.smooth = true;
      auto_save.session = true;

      # dark-ish
      colors.webpage.preferred_color_scheme = "dark"; # tell sites you prefer dark
      colors.webpage.darkmode.enabled = false; # true = force-invert every site (aggressive, breaks some pages)

      # built-in ad/tracker blocking (Brave's ABP lists) — no extension needed
      content.blocking.method = "both"; # adblock lists + hosts file

      downloads.location.directory = "${config.home.homeDirectory}/downloads";
    };

    searchEngines = {
      DEFAULT = "https://duckduckgo.com/?q={}";
      nix = "https://search.nixos.org/packages?query={}";
      hm = "https://home-manager-options.extranix.com/?query={}";
    };

    keyBindings = {
      normal = {
        ",t" = "config-cycle tabs.show never multiple"; # toggle the tab bar on demand
        # ",m" = "spawn mpv {url}";                       # e.g. hand a page to mpv
      };
    };

    loadAutoconfig = false;
  };
}
