{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.qemu-live-migrate;

  # writeShellApplication is a newer, safer Nix tool than writeShellScriptBin
  # It automatically runs ShellCheck on your code during the build.
  migrateScript = pkgs.writeShellApplication {
    name = "qemu-live-migrate";

    # Implicitly sets up the PATH so the script has access to these commands
    runtimeInputs = with pkgs; [libvirt openssh];

    text = ''
      # Set default user from the Nix configuration
      TARGET_USER="${cfg.defaultUser}"
      TARGET_IP=""

      # Parse optional flags: -u for user, -i for IP, -h for help
      while getopts "u:i:h" opt; do
        case $opt in
          u) TARGET_USER="$OPTARG" ;;
          i) TARGET_IP="$OPTARG" ;;
          h)
            echo "Usage: qemu-live-migrate [-u user] [-i target_ip] vm1 [vm2 ...]"
            echo "  -u  SSH user for target host (default: ${cfg.defaultUser})"
            echo "  -i  Target host IP (default: auto-detected based on cluster node)"
            exit 0
            ;;
          \?) echo "Invalid option. Use -h for help."; exit 1 ;;
        esac
      done

      # Shift the parsed flags out of the way. What remains are the VM names.
      shift $((OPTIND -1))
      VMS=("$@")

      if [ ''${#VMS[@]} -eq 0 ]; then
        echo "Error: No VMs specified."
        echo "Usage: qemu-live-migrate [-u user] [-i target_ip] vm1 [vm2 ...]"
        exit 1
      fi

      # Auto-detect IP if not provided (assumes node1/node2 cluster)
      if [ -z "$TARGET_IP" ]; then
        case "$(hostname)" in
          node1) TARGET_IP="192.168.1.100" ;;
          node2) TARGET_IP="192.168.1.99" ;;
          *) echo "Error: Unknown host and no target IP (-i) provided."; exit 1 ;;
        esac
      fi

      # Loop through the remaining arguments (the VMs)
      for VM in "''${VMS[@]}"; do
        echo "=================================================="
        echo "Starting live migration for: $VM"
        echo "Target: qemu+ssh://$TARGET_USER@$TARGET_IP/system"
        echo "=================================================="

        # We use 'sudo' here because virsh often requires root, but if your
        # user is in the libvirt group, you can remove sudo.
        sudo virsh migrate --live --copy-storage-inc --persistent --verbose --auto-converge \
          "$VM" \
          "qemu+ssh://$TARGET_USER@$TARGET_IP/system" \
          --migrateuri "tcp://$TARGET_IP"

        echo "Migration of $VM complete."
        echo
      done
    '';
  };
in {
  options.programs.qemu-live-migrate = {
    enable = mkEnableOption "QEMU Live Migration CLI helper script";

    defaultUser = mkOption {
      type = types.str;
      default = "root";
      description = "Default SSH user used for live migration. Can be overridden with -u flag.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [migrateScript];
  };
}
