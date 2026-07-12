{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # This tells Nix to use the unstable branch for this specific variable
  unstable = import inputs.nixpkgs-unstable {
    system = "x86_64-linux"; # Standard for most PCs
    config.allowUnfree = true;
  };
in {
  # ... your existing config ...{
  imports = [
    ./hardware-configuration.nix
  ];
  environment.systemPackages = [
    # This pulls the exact 'ErebOS' package you were running
    # and installs it as 'nvim' on your system path.
    inputs.nvf-custom.packages.${pkgs.system}.default
    pkgs.hyprpaper
    pkgs.hyprshot
    pkgs.sbctl
    pkgs.nfs-utils
  ];
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.samba-wsdd.enable = true;

  boot.supportedFilesystems = ["nfs"];
  # for ollamprograms.adb.enable = true;a
  programs.adb.enable = true;

  systemd.services.NetworkManager-wait-online.enable = false;
  # Kill that xrdb error once and for all
  # We still enable the module so Nix knows how to handle the manual/docs
  # but we don't need to define 'settings' if you just want the fork's defaults.

  # IMPORTANT: Stylix usually kills custom Neovim themes.
  # Disable it so your fork's Catppuccin theme actually shows up.
  # for just cause 4
  networking.extraHosts = ''
    127.0.0.1 square-enix.com
    127.0.0.1 www.square-enix.com
  '';
  virtualisation.docker.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader = {
    grub = {
      enable = lib.mkForce false;
      efiSupport = true;
      devices = ["nodev"];
      configurationName = "BowOS";
      fontSize = 26;
      useOSProber = true;
    };
    efi = {
      canTouchEfiVariables = true;
      # Optional: specify EFI mount point if non-standard
      efiSysMountPoint = "/boot";
    };
  };
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking.hostName = "ErebOS";
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [pkgs.networkmanager-openvpn];

  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.deathraymind = {
    shell = pkgs.zsh;
    hashedPassword = "$y$j9T$Yu6LVySFa46PsKBHC7lkI.$fCdSJMULL1L2uOMhiY1WlR5QzW84qP42ktl2CxvSkgC";
    isNormalUser = true;
    extraGroups = ["docker" "dialout" "networkmanager" "wheel" "libvirtd" "vboxusers" "disk" "kvm" "video" "render" "docker" "adbusers" "ydotool" "uinput" "amdgpu"];

    packages = with pkgs; [
    ];
  };
  # Make sure amdgpu is available from early boot and in the live system
  boot.initrd.kernelModules = ["amdgpu"];
  boot.kernelModules = ["amdgpu"];

  # You need access to /dev/kfd and /dev/dri/*

  ## Home Manager Import ##
  ErebOS.steam.enable = true;
  ErebOS.stylix = {
    enable = true;
    theme = "oxocarbon-dark";
  };

  services.openssh.enable = true;
  ErebOS.cachy.enable = true;
  ErebOS.autologin.enable = true;

  hardware.bluetooth.enable = true;
  services.upower.enable = true; # Needed for battery status

  system.stateVersion = "25.05";

  # 1. Enable dconf (Required for the GNOME portal to function)
  programs.gamemode.enable = true;
  programs.dconf.enable = true;
  fileSystems."/mnt/data" = {
    device = "192.168.1.100:/srv/share";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=600"];
  };
}
