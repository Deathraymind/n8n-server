{pkgs, ...}: {
  networking.hostName = "proxmox-vm";

  # Enable Proxmox Guest Agent so the Proxmox UI can see the VM's IP address
  services.qemuGuest.enable = true;

  # Enable SSH service
  services.openssh.enable = true;

  # Define your user and inject your SSH public key for instant access
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." # <-- REPLACE WITH YOUR ACTUAL SSH PUBLIC KEY
  ];

  # System packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
