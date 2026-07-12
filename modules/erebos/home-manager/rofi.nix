{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.ErebOS.rofi;

  # --- CUSTOMIZABLE VARIABLES ---
  # Change these to update the look across the entire config
  settings = {
    font = "JetBrainsMono Nerd Font Mono 12";
    iconTheme = "Papirus";

    # Dimensions
    windowWidth = "30%";
    entryWidth = "20%";
    buttonWidth = "5%";
    iconSize = "36px";

    # Gaps and Spacing
    marginTop = "4px 0px 0px 0px";
    windowSpacing = "4px";
    mainboxPadding = "15px";
    listboxSpacing = "10px";
    listboxPadding = "10px";
    elementSpacing = "10px";
    elementPadding = "10px";
    inputMargin = "10px";
    entryPadding = "10px";
    buttonPadding = "12px";
    textPadding = "12px";

    # Borders and Radii
    borderWidth = "1px";
    windowRadius = "15px";
    entryRadius = "15px";
    buttonRadius = "15px";
    elementRadius = "15px";
    inputRadius = "15px";
    msgRadius = "15px";
    errorRadius = "15px";

    # Behavior
    columns = 2;
    lines = 5;
  };
in {
  options.ErebOS.rofi = {
    enable = lib.mkEnableOption "ErebOS rofi Configuration";
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      layerrule = [
        "animation slide top, match:namespace ^(rofi)$"
      ];
    };
    programs = lib.mkForce {
      rofi = {
        enable = true;
        package = pkgs.rofi;
        extraConfig = {
          modi = "drun"; #drun,filebrowser,run doing this will do stuff
          show-icons = true;
          icon-theme = settings.iconTheme;
          location = 2;
          font = settings.font;
          drun-display-format = "{icon} {name}";
          display-drun = " Apps";
          #display-run = " Run";
          #display-filebrowser = " File";
        };
        theme = let
          inherit (config.lib.formats.rasi) mkLiteral;
        in {
          "*" = {
            bg = mkLiteral "#${config.stylix.base16Scheme.base00}";
            bg-alt = mkLiteral "#${config.stylix.base16Scheme.base09}";
            foreground = mkLiteral "#${config.stylix.base16Scheme.base01}";
            selected = mkLiteral "#${config.stylix.base16Scheme.base09}";
            active = mkLiteral "#${config.stylix.base16Scheme.base0B}";
            text-selected = mkLiteral "#${config.stylix.base16Scheme.base00}";
            text-color = mkLiteral "#${config.stylix.base16Scheme.base05}";
            border-color = mkLiteral "#${config.stylix.base16Scheme.base03}";
            urgent = mkLiteral "#${config.stylix.base16Scheme.base0E}";
          };
          "window" = {
            width = mkLiteral settings.windowWidth;
            transparency = "real";
            margin = mkLiteral settings.marginTop;
            orientation = mkLiteral "vertical";
            cursor = mkLiteral "default";
            spacing = mkLiteral settings.windowSpacing;
            border = mkLiteral settings.borderWidth;
            border-color = "@border-color";
            border-radius = mkLiteral settings.windowRadius;
            background-color = mkLiteral "@bg";
          };
          "mainbox" = {
            padding = mkLiteral settings.mainboxPadding;
            enabled = true;
            orientation = mkLiteral "vertical";
            children = map mkLiteral [
              "inputbar"
              "listbox"
            ];
            background-color = mkLiteral "transparent";
          };
          "inputbar" = {
            enabled = true;
            margin = mkLiteral settings.inputMargin;
            background-color = mkLiteral "transparent";
            border-radius = settings.inputRadius;
            orientation = mkLiteral "horizontal";
            children = map mkLiteral [
              "entry"
              "dummy"
              "mode-switcher"
            ];
          };
          "entry" = {
            enabled = true;
            expand = false;
            width = mkLiteral settings.entryWidth;
            padding = mkLiteral settings.entryPadding;
            border-radius = mkLiteral settings.entryRadius;
            background-color = mkLiteral "@selected";
            text-color = mkLiteral "@text-selected";
            cursor = mkLiteral "text";
            placeholder = "🖥️ Search ";
            placeholder-color = mkLiteral "inherit";
          };
          "listbox" = {
            spacing = mkLiteral settings.listboxSpacing;
            padding = mkLiteral settings.listboxPadding;
            background-color = mkLiteral "transparent";
            orientation = mkLiteral "vertical";
            children = map mkLiteral [
              "message"
              "listview"
            ];
          };
          "listview" = {
            enabled = true;
            columns = settings.columns;
            lines = settings.lines;
            cycle = true;
            dynamic = true;
            scrollbar = false;
            layout = mkLiteral "vertical";
            reverse = false;
            fixed-height = true;
            fixed-columns = true;
            spacing = mkLiteral "10px";
            background-color = mkLiteral "transparent";
            border = mkLiteral "0px";
          };
          "dummy" = {
            expand = true;
            background-color = mkLiteral "transparent";
          };
          "mode-switcher" = {
            enabled = true;
            spacing = mkLiteral "10px";
            background-color = mkLiteral "transparent";
          };
          "button" = {
            width = mkLiteral settings.buttonWidth;
            padding = mkLiteral settings.buttonPadding;
            border-radius = mkLiteral settings.buttonRadius;
            background-color = mkLiteral "@text-selected";
            text-color = mkLiteral "@text-color";
            cursor = mkLiteral "pointer";
          };
          "button selected" = {
            background-color = mkLiteral "@selected";
            text-color = mkLiteral "@text-selected";
          };
          "scrollbar" = {
            width = mkLiteral "4px";
            border = 0;
            handle-color = mkLiteral "@border-color";
            handle-width = mkLiteral "8px";
            padding = 0;
          };
          "element" = {
            enabled = true;
            spacing = mkLiteral settings.elementSpacing;
            padding = mkLiteral settings.elementPadding;
            border-radius = mkLiteral settings.elementRadius;
            background-color = mkLiteral "transparent";
            cursor = mkLiteral "pointer";
          };
          "element normal.normal" = {
            background-color = mkLiteral "inherit";
            text-color = mkLiteral "inherit";
          };
          "element normal.urgent" = {
            background-color = mkLiteral "@urgent";
            text-color = mkLiteral "@foreground";
          };
          "element normal.active" = {
            background-color = mkLiteral "@active";
            text-color = mkLiteral "@foreground";
          };
          "element selected.normal" = {
            background-color = mkLiteral "@selected";
            text-color = mkLiteral "@text-selected";
          };
          "element selected.urgent" = {
            background-color = mkLiteral "@urgent";
            text-color = mkLiteral "@text-selected";
          };
          "element selected.active" = {
            background-color = mkLiteral "@urgent";
            text-color = mkLiteral "@text-selected";
          };
          "element alternate.normal" = {
            background-color = mkLiteral "transparent";
            text-color = mkLiteral "inherit";
          };
          "element alternate.urgent" = {
            background-color = mkLiteral "transparent";
            text-color = mkLiteral "inherit";
          };
          "element alternate.active" = {
            background-color = mkLiteral "transparent";
            text-color = mkLiteral "inherit";
          };
          "element-icon" = {
            background-color = mkLiteral "transparent";
            text-color = mkLiteral "inherit";
            size = mkLiteral settings.iconSize;
            cursor = mkLiteral "inherit";
          };
          "element-text" = {
            background-color = mkLiteral "transparent";
            font = settings.font;
            text-color = mkLiteral "inherit";
            cursor = mkLiteral "inherit";
            vertical-align = mkLiteral "0.5";
            horizontal-align = mkLiteral "0.0";
          };
          "message" = {
            background-color = mkLiteral "transparent";
            border = mkLiteral "0px";
          };
          "textbox" = {
            padding = mkLiteral settings.textPadding;
            border-radius = mkLiteral settings.msgRadius;
            background-color = mkLiteral "@bg-alt";
            text-color = mkLiteral "@bg";
            vertical-align = mkLiteral "0.5";
            horizontal-align = mkLiteral "0.0";
          };
          "error-message" = {
            padding = mkLiteral settings.textPadding;
            border-radius = mkLiteral settings.errorRadius;
            background-color = mkLiteral "@bg-alt";
            text-color = mkLiteral "@bg";
          };
        };
      };
    };
  };
}
