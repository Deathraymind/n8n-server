{ config, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "mydatabase" ];
    authentication = pkgs.lib.mkOverride 10 [
      # type  database  user   auth-method
      { type = "local"; database = "all"; user = "all"; method = "trust"; }
    ];
  };
}

