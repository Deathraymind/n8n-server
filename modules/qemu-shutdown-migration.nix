# qemu-shutdown-migration.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.qemu-evacuate-on-shutdown;
  migrate = config.programs.qemu-live-migrate.package;

  evacuateScript = pkgs.writeShellScript "qemu-evacuate" ''
    set -u
    TARGET_IP="${cfg.targetIp}"

    if ! ping -c 4 -W 2 "$TARGET_IP" >/dev/null 2>&1; then
      echo "WARNING: peer $TARGET_IP unreachable after 4 pings. Skipping evacuation." >&2
      exit 0
    fi

    for VM in ${escapeShellArgs cfg.vms}; do
      if ! virsh list --state-running --name | grep -qx "$VM"; then
        echo "$VM not running here; nothing to evacuate."
        continue
      fi
      # One VM per call so a single failure doesn't abort the rest
      # (the migrate script uses set -e internally)
      if ${migrate}/bin/qemu-live-migrate -u root -i "$TARGET_IP" "$VM"; then
        echo "$VM evacuated."
      else
        echo "WARNING: evacuation of $VM FAILED; it will die with the host." >&2
      fi
    done
    exit 0
  '';
in {
  options.services.qemu-evacuate-on-shutdown = {
    enable = mkEnableOption "live-migrate VMs to the peer node on shutdown";
    vms = mkOption {
      type = types.listOf types.str;
      description = "VMs to evacuate if running locally at shutdown.";
    };
    targetIp = mkOption {
      type = types.str;
      description = "Peer node IP to evacuate to.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.qemu-live-migrate.enable;
        message = "qemu-evacuate-on-shutdown requires programs.qemu-live-migrate.enable = true";
      }
    ];

    systemd.services.qemu-evacuate-on-shutdown = {
      description = "Evacuate running VMs to peer before shutdown";
      restartIfChanged = false;
      wantedBy = ["multi-user.target"];
      after = ["network.target" "libvirtd.service"];
      requires = ["libvirtd.service"];
      path = with pkgs; [libvirt openssh iputils gnugrep];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = evacuateScript;
        TimeoutStopSec = "15min";
      };
    };
  };
}
