{ config, pkgs, ... }:

{
  config.services.postgresql = {
    enable = true;
     enableTCPIP = true;
    ensureDatabases = [ "mydatabase" ];
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
      host  all       all     127.0.0.1/32   trust
      host  all       all     ::1/128        trust
      host    all     all     192.168.1.0/24   md5
    '';
    initialScript = pkgs.writeText "init.sql" ''
        ALTER USER postgres WITH PASSWORD '6255';
    '';

  };
}
