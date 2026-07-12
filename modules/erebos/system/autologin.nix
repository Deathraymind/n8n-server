{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.ErebOS.autologin;
in {
  ### 1. Define the "Switch"
  options.ErebOS.autologin = {
    enable = lib.mkEnableOption "ErebOS autologin Configuration";
  };

  ### 2. The Logic
  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          # Replace 'yourusername' with your actual NixOS username
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd 'niri-session'";
          user = "deathraymind";
        };
      };
    };

    # This helps tuigreet look clean on boot
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };
  };
}
