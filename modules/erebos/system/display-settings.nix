{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  hardware.i2c.enable = true; # loads i2c-dev, sets up the i2c group
  users.users.deathraymind.extraGroups = ["i2c"];
}
