{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.qemu-evacuate-on-shutdown;

  evacuateScript = pkgs.writeShellScript "qemu-evacuate" ''
    set -u

    TARGET_IP="${cfg.targetIp}"

    # Peer health check: 4 pings, then give up and allow shutdown
    if ! ping -c 4 -W 2 "$TARGET_IP" >/dev/null 2>&1; then
      echo "WARNING: peer $TARGET_IP unreachable after 4 pings. Skipping evacuation; VMs will die with the host." >&2
      exit 0
    fi

    for VM in ${escapeShellArgs cfg.vms}; do
      # Only evacuate what is actually running here
      if ! virsh list --state-running --name | grep -qx "$VM"; then
        echo "$VM not running here; nothing to evacuate."
        continue
      fi

      echo "Evacuating $VM to $TARGET_IP..."
      if virsh migrate --live --copy-storage-inc --persistent --undefinesource \
           --verbose --auto-converge "$VM" \
           "qemu+ssh://root@$TARGET_IP/system" \
           --migrateuri "tcp://$TARGET_IP"; then
        echo "$VM evacuated."
      else
        echo "WARNING: evacuation of $VM FAILED; it will be shut down with the host." >&2
      fi
    done

    exit 0  # never block shutdown
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
      example = "192.168.1.100";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.qemu-evacuate-on-shutdown = {
      description = "Evacuate running VMs to peer before shutdown";
      wantedBy = ["multi-user.target"];
      # Stop ordering = reverse of this: our ExecStop runs while these are still up
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
