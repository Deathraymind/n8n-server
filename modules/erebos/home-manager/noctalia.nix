{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.ErebOS.homeNoctalia;

  # This is an HM module; stylix's HM half is auto-imported by the system
  # stylix module (homeManagerIntegration.autoImport), so config.stylix and
  # config.lib.stylix exist here whenever ErebOS.stylix is enabled.
  # `or false` keeps this module eval-safe if stylix is ever absent.
  stylixOn = cfg.followStylix && (config.stylix.enable or false);

  # withHashtag -> "#rrggbb", which is exactly what noctalia's hex() parser
  # and the community palette format expect.
  c = config.lib.stylix.colors.withHashtag;

  themeMode =
    if (config.stylix.polarity or "dark") == "light"
    then "light"
    else "dark";

  # base16 -> noctalia's 16 color roles. Left column comments = role meaning
  # per the community-palettes spec; mapping identical to the v4 target.
  stylixPaletteMode = {
    mPrimary = c.base0D; #   accent: active elements, highlights
    mOnPrimary = c.base00; # text/icons drawn on mPrimary
    mSecondary = c.base0E;
    mOnSecondary = c.base00;
    mTertiary = c.base0C;
    mOnTertiary = c.base00;
    mError = c.base08;
    mOnError = c.base00;
    mSurface = c.base00; #   main background
    mOnSurface = c.base05; # main text color
    mSurfaceVariant = c.base01; # raised/inset surfaces
    mOnSurfaceVariant = c.base04;
    mOutline = c.base03; #   borders and dividers
    mShadow = c.base00;
    mHover = c.base0C;
    mOnHover = c.base00;

    # Standard base16 terminal mapping (same one stylix uses for kitty etc).
    # REQUIRED by the parser — a palette without it is rejected entirely.
    terminal = {
      normal = {
        black = c.base00;
        red = c.base08;
        green = c.base0B;
        yellow = c.base0A;
        blue = c.base0D;
        magenta = c.base0E;
        cyan = c.base0C;
        white = c.base05;
      };
      bright = {
        black = c.base03;
        red = c.base08;
        green = c.base0B;
        yellow = c.base0A;
        blue = c.base0D;
        magenta = c.base0E;
        cyan = c.base0C;
        white = c.base07;
      };
      foreground = c.base05;
      background = c.base00;
      cursor = c.base05;
      cursorText = c.base00;
      selectionFg = c.base05;
      selectionBg = c.base02;
    };
  };
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  options.ErebOS.homeNoctalia = {
    enable = lib.mkEnableOption "ErebOS Noctalia Shell Configuration";

    followStylix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Generate a noctalia custom palette from the active stylix base16
        scheme and select it. Disable to manage noctalia theming yourself
        (or once stylix grows a native v5 target).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.noctalia = {
      enable = true;
      customPalettes = lib.optionalAttrs stylixOn {
        stylix.dark = stylixPaletteMode;
      };

      # NOTE: plain attrset merge (optionalAttrs), not mkIf — `settings` is
      # a freeform TOML type, and mkIf markers nested inside freeform values
      # don't reliably resolve.
      settings =
        {
          # v5 bars are named tables: [bar.<name>]. "default" replaces the
          # old v4 `bar.position` setting (and "top" is also the v5 default).
          bar.default.position = "right";
        }
        // lib.optionalAttrs stylixOn {
          shell.font_family = config.stylix.fonts.sansSerif.name;

          theme = {
            source = "custom"; # PaletteSource::Custom
            custom_palette = "stylix"; # -> palettes/stylix.json
            mode = themeMode; # from stylix.polarity
          };
        };
    };
  };
}
