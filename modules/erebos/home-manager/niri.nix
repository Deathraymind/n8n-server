# This is depricated dont use for now, DO NOT EDIT UNLESS TOLD
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.ErebOS.homeNiri;
in {
  imports = [
    inputs.niri.homeModules.niri
  ];
  options.ErebOS.homeNiri = {
    enable = lib.mkEnableOption "ErebOS Niri Compositor Configuration";
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      xwayland-satellite
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_DESKTOP = "niri";
      NIXOS_OZONE_WL = "1";
    };
    # Apply the check override
    nixpkgs.overlays = [
      (final: prev: {
        niri = prev.niri.overrideAttrs (oldAttrs: {
          doCheck = false;
        });
      })
    ];
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config = {
        common = {
          default = ["gtk"];
        };
        # This specifically stops GNOME apps from waiting for gnome-shell
        niri = {
          default = ["gnome" "gtk"];
        };
      };
    };

    programs.niri = {
      enable = true;
      package = pkgs.niri;

      settings = {
        animations = {
          window-open = {
            kind.easing = {
              curve = "linear";
              duration-ms = 500;
            };
            # Nix will read the contents of the file and insert it here
            custom-shader = builtins.readFile ./niri-animations/honeycomb-open.glsl;
          };
          window-close = {
            kind.easing = {
              curve = "linear";
              duration-ms = 400;
            };
            custom-shader = builtins.readFile ./niri-animations/honeycomb-close.glsl;
          };
        };
        prefer-no-csd = false;
        spawn-at-startup = [
          {command = ["xwayland-satellite"];} # Add this line
          {
            command = [
              "${pkgs.dbus}/bin/dbus-update-activation-environment"
              "--systemd"
              "DISPLAY"
              "WAYLAND_DISPLAY"
              "XDG_CURRENT_DESKTOP"
              "XDG_SESSION_DESKTOP"
            ];
          }
          {
            # This block is the "magic" for screencasting
            command = [
              "sh"
              "-c"
              ''
                ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri XDG_SESSION_DESKTOP=niri
                  
                systemctl --user stop xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
                  
                systemctl --user start xdg-desktop-portal-gnome xdg-desktop-portal-gtk              ''
            ];
          }
          {command = ["noctalia"];}
        ];

        input = {
          mouse = {
            accel-profile = "flat";
          };
          keyboard.xkb.layout = "us";
          focus-follows-mouse = {
            enable = true;
            max-scroll-amount = "10%";
          };
          warp-mouse-to-focus = true;
        };

        outputs = {
          "HDMI-A-1" = {
            scale = 1.5;
            mode = {
              width = 3840;
              height = 2160;
              refresh = 59.997;
            };
            transform = {
              rotation = 180;
              flipped = false;
            };
            position = {
              x = 0;
              y = 0;
            }; # top monitor
          };

          "DP-2" = {
            mode = {
              width = 2560;
              height = 1440;
              refresh = 164.998;
            };
            position = {
              x = 0;
              y = 1440;
            }; # below DP-2
          };
          "HDMI-A" = {
            mode = {
              width = 1920;
              height = 1080;
              refresh = 70.0;
            };
            transform = {
              rotation = 90;
              flipped = false;
            };

            position = {
              x = -1080;
              y = 1000;
            };
          };
        };

        layout = {
          preset-column-widths = [
            {proportion = 0.5;}
            {proportion = 1.0;}
          ];
          gaps = 12;
          struts = {
            left = 12;
            right = 12;
            top = 12;
            bottom = 12;
          };
          border = {
            enable = true;
            width = 1;
            active.color = "#${config.lib.stylix.colors.base03}"; # Note: used config.lib.stylix for safety
            inactive.color = "#${config.lib.stylix.colors.base01}";
          };
          focus-ring = {
            enable = true;
            width = 1;
            active.color = "#${config.lib.stylix.colors.base03}";
            inactive.color = "#${config.lib.stylix.colors.base01}";
          };
        };

        window-rules = [
          {
            matches = []; # Empty matches applies to all windows
            draw-border-with-background = false;
          }
          {
            matches = [];
            default-column-width = {proportion = 0.4;};
          }
          {
            matches = [];
            geometry-corner-radius = {
              top-left = 12.0;
              top-right = 12.0;
              bottom-left = 12.0;
              bottom-right = 12.0;
            };
            clip-to-geometry = true;
          }
        ];

        binds = {
          # Move columns/windows (The "Shift" actions you requested)
          "Mod+Shift+H".action.move-column-left = [];
          "Mod+Shift+L".action.move-column-right = [];
          "Mod+Minus".action.set-column-width = ["-10%"];
          "Mod+Equal".action.set-column-width = ["+10%"]; # Moving "Up" or "Down" moves the window/column to the workspace above or below
          "Mod+Shift+K".action.move-window-up-or-to-workspace-up = [];
          "Mod+Shift+J".action.move-window-down-or-to-workspace-down = [];

          # Optional: Consume or Expel windows from a column
          "Mod+BracketLeft".action.consume-or-expel-window-left = [];
          "Mod+BracketRight".action.consume-or-expel-window-right = [];
          "Mod+O".action.toggle-overview = [];
          "Mod+T".action.spawn = ["kitty"];
          "Mod+Q".action.close-window = [];
          "Mod+A".action.spawn = ["rofi" "-show" "drun"];
          "Mod+P".action.spawn = ["hypersnip"];
          "Mod+W".action.toggle-window-floating = [];
          "Mod+I".action.spawn = ["wl-color-picker"];
          "Alt+Return".action.switch-preset-column-width = [];
          "Mod+Shift+F".action.fullscreen-window = [];
          "Mod+H".action.focus-column-left = [];
          "Mod+L".action.focus-column-right = [];
          "Mod+K".action.focus-window-or-workspace-up = [];
          "Mod+J".action.focus-window-or-workspace-down = [];
          "XF86AudioPlay".action.spawn = ["playerctl" "play-pause"];
          "XF86AudioNext".action.spawn = ["playerctl" "next"];
          "XF86MonBrightnessUp".action.spawn = ["brightnessctl" "set" "5%+"];
          "XF86AudioRaiseVolume".action.spawn = ["wpctl" "set-volume" "-l" "1.0" "@DEFAULT_SINK@" "5%+"];
        };
      };
    };
  };
}
