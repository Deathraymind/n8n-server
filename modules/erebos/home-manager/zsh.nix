{ lib, config, pkgs, ... }:
let
  cfg = config.ErebOS.zsh;  
in 
{
  ### 1. Define the "Switch"
  options.ErebOS.zsh = {
    enable = lib.mkEnableOption "ErebOS zsh Configuration";
  };

  ### 2. The Logic (Home Manager only!)
  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true; 
    };
  };
}
