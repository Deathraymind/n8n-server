# modules/erebos/home-manager/noctalia.nix
#
# ErebOS Noctalia (v5) + Stylix bridge.
#
# Noctalia v5 has no stylix target (stylix release-26.05 only targets the
# frozen v4 `programs.noctalia-shell`), so this module wires the two together
# directly:
#
#   stylix base16 scheme (config.lib.stylix.colors)
#     -> noctalia custom palette JSON  (~/.config/noctalia/palettes/stylix.json)
#     -> [theme] source = "custom", custom_palette = "stylix"
#
# The 16-role color mapping is ported from stylix's v4 noctalia-shell target
# (modules/noctalia-shell/hm.nix @ e602ad04). Noctalia expands these 16 roles
# into its full Material-3 token set itself (containers, fixed variants,
# surface tiers) with WCAG contrast enforcement — see expandFixedPaletteMode()
# in src/theme/fixed_palette.cpp — so we only supply the core roles plus the
# terminal ANSI block (which base16 maps onto by construction).
#
# Palette JSON schema verified against noctalia main @ 2026-07-13:
#   - parseCommunityPaletteJson() in src/theme/theme_service.cpp:
#       * "dark" object REQUIRED, and its "terminal" object REQUIRED
#       * "light" optional -> falls back to dark (base16 schemes are
#         single-polarity, so we rely on that fallback deliberately)
#   - color keys accept "mPrimary" (m-prefixed camelCase) or "primary";
#     we use the m-prefixed form to match the community-palettes convention.
#
# Delete this module (or set followStylix = false) when stylix ships a
# native v5 target. Check with:
#   grep -rn "programs.noctalia\b" <stylix>/modules/
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

      # Ships as ~/.config/noctalia/palettes/stylix.json via the HM module.
      # Only "dark" is emitted: the parser copies dark -> light when light
      # is absent, which is the honest behavior for a single-polarity
      # base16 scheme.
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
          bar.default.position = "top";
        }
        // lib.optionalAttrs stylixOn {
          # Follow the stylix font for the shell UI. Empty/absent falls
          # back to sans-serif; key verified in shellSchema().
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
