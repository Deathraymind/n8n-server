{modulesPath, ...}: {
  imports = [
    # Built-in NixOS profile for Proxmox KVM virtualisation
    (modulesPath + "/virtualisation/proxmox-image.nix")
  ];

  # Basic hardware tweaks for virtual machines
  nixpkgs.hostPlatform = "x86_64-linux";

  # Tell Proxmox to dynamically adjust disk size if needed
  virtualisation.diskSize = 10240; # Initial disk size in MB (10 GB)
}
