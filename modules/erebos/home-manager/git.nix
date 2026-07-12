{lib, config, inputs, ...}:
let
 cfg = config.ErebOS.git;  
in 
{

 ### 1. Define the "Switch"
  options.ErebOS.git= {
    enable = lib.mkEnableOption "ErebOS git Configuration";
  };

  ### 2. The Logic
  config = lib.mkIf cfg.enable {
 


programs.git = {
      enable = true;
      settings.user = {
       name = "Deathraymind";
       email = "deathraymind@gmail.com";
      };
    };
    };
}
