{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.qemu-live-migrate;

  migrateScript = pkgs.writeShellApplication {
    name = "qemu-live-migrate";

    runtimeInputs = with pkgs; [libvirt openssh];

    text = ''
      # Set defaults from the Nix configuration
      TARGET_USER="${cfg.defaultUser}"

      # If Nix provides a default IP, inject it here. Otherwise, leave it blank.
      TARGET_IP="${
        if cfg.defaultIp != null
        then cfg.defaultIp
        else ""
      }"

      # Parse optional flags: -u for user, -i for IP, -h for help
      while getopts "u:i:h" opt; do
        case $opt in
          u) TARGET_USER="$OPTARG" ;;
          i) TARGET_IP="$OPTARG" ;; # This overrides the Nix default
          h)
            echo "Usage: qemu-live-migrate [-u user] [-i target_ip] vm1 [vm2 ...]"
            echo "  -u  SSH user for target host (default: ${cfg.defaultUser})"
            echo "  -i  Target host IP (configured default: ''${TARGET_IP:-auto-detect})"
            exit 0
            ;;
          \?) echo "Invalid option. Use -h for help."; exit 1 ;;
        esac
      done

      shift $((OPTIND -1))
      VMS=("$@")

      if [ ''${#VMS[@]} -eq 0 ]; then
        echo "Error: No VMs specified."
        echo "Usage: qemu-live-migrate [-u user] [-i target_ip] vm1 [vm2 ...]"
        exit 1
      fi

      # Auto-detect IP if no -i flag was passed AND no Nix default was configured
      if [ -z "$TARGET_IP" ]; then
        case "$(hostname)" in
          node1) TARGET_IP="192.168.1.100" ;;
          node2) TARGET_IP="192.168.1.99" ;;
          *) echo "Error: Unknown host and no target IP provided via config or -i flag."; exit 1 ;;
        esac
      fi

      for VM in "''${VMS[@]}"; do
        echo "=================================================="
        echo "Starting live migration for: $VM"
        echo "Target: qemu+ssh://$TARGET_USER@$TARGET_IP/system"
        echo "=================================================="

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

    defaultIp = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default target IP for live migration. If unset, the script will attempt to auto-detect based on node name.";
      example = "192.168.1.100";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [migrateScript];
  };
}
