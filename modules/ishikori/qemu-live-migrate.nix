# qemu-live-migrate.nix
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
      TARGET_USER="${cfg.defaultUser}"
      TARGET_IP="${
        if cfg.defaultIp != null
        then cfg.defaultIp
        else ""
      }"
      while getopts "u:i:h" opt; do
        case $opt in
          u) TARGET_USER="$OPTARG" ;;
          i) TARGET_IP="$OPTARG" ;;
          h)
            echo "Usage: qemu-live-migrate [-u user] [-i target_ip] vm1 [vm2 ...]"
            exit 0
            ;;
          \?) echo "Invalid option. Use -h for help."; exit 1 ;;
        esac
      done
      shift $((OPTIND -1))
      VMS=("$@")
      if [ ''${#VMS[@]} -eq 0 ]; then
        echo "Error: No VMs specified."
        exit 1
      fi
      if [ -z "$TARGET_IP" ]; then
        case "$(hostname)" in
          node1) TARGET_IP="192.168.1.100" ;;
          node2) TARGET_IP="192.168.1.99" ;;
          *) echo "Error: Unknown host and no target IP provided."; exit 1 ;;
        esac
      fi

      # Use sudo only when not already root (systemd services run as root)
      SUDO=""
      if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

      for VM in "''${VMS[@]}"; do
        echo "=================================================="
        echo "Starting live migration for: $VM"
        echo "Target: qemu+ssh://$TARGET_USER@$TARGET_IP/system"
        echo "=================================================="
        $SUDO virsh migrate --live --undefinesource --copy-storage-inc --persistent --verbose --auto-converge \
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
      description = "Default target IP for live migration.";
      example = "192.168.1.100";
    };
    package = mkOption {
      type = types.package;
      readOnly = true;
      default = migrateScript;
      description = "The migration script package, for use by other modules.";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [migrateScript];
  };
}
