{ config, pkgs, ... }:
{

services.jellyfin = {
    enable = true;
    openFirewall = true;
    extraPackages = with pkgs; [
    intel-media-driver
  ];
  }; 
hardware.opengl = {
  enable = true;
  extraPackages = with pkgs; [
    intel-media-driver   # Intel's official VAAPI driver (recommended for newer Xeons)
    libva-utils           # For testing VAAPI (optional)
  ];
}; 
}

