{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  # The generic VHD generator labels the main system partition as "nixos"
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Xen console support so your boot logs stream straight to Xen Orchestra's console tab
  boot.kernelParams = ["console=hvc0"];
}
