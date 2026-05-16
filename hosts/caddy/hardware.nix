{modulesPath, ...}: {
  imports = [
    # Built-in NixOS profile for Proxmox KVM virtualisation
    (modulesPath + "/virtualisation/proxmox-image.nix")
  ];

  # Basic hardware tweaks for virtual machines
  nixpkgs.hostPlatform = "x86_64-linux";
  proxmox.qemu.diskSize = "20G";
  # Tell Proxmox to dynamically adjust disk size if needed
}
