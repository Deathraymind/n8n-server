{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.qemu-incremental-backup-nightly;

  backupScript = pkgs.writeShellScriptBin "qemu-incremental-backup" ''
    set -euo pipefail

    # Securely map the Nix list to a bash array
    eval "VMS=(${escapeShellArgs cfg.vms})"

    OVERLAY_NAME="daily"
    DISK="vda"

    # Much cleaner! We just grab the IP directly from your Nix configuration.
    PEER="${cfg.peerIp}"

    # Global lock prevents cron overlaps if a sync takes longer than 24h
    exec 9>/tmp/pelican-daily.lock
    flock -n 9 || { echo "another run in progress; skipping"; exit 0; }

    OVERALL_STATUS=0

    for VM in "''${VMS[@]}"; do
      echo "=================================================="
      echo "Starting backup cycle for VM: $VM"
      echo "=================================================="

      IMGDIR="/var/lib/libvirt/images/$VM"
      BASE="$IMGDIR/$VM.qcow2"
      STUB="$IMGDIR/$VM.$OVERLAY_NAME"

      # GUARD 1 (source): only proceed if the VM is live HERE
      if ! virsh list --state-running --name | grep -qx "$VM"; then
        echo "$VM not running locally; not the source tonight. Skipping."
        continue
      fi

      # GUARD 2 (dest): never push onto a node that's ALSO running the VM.
      if ! peer_vms=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "root@$PEER" \
            "virsh list --state-running --name" 2>&1); then
        echo "ABORT: cannot verify peer state ($PEER unreachable) for $VM: $peer_vms"
        OVERALL_STATUS=1
        continue
      fi

      if grep -qx "$VM" <<< "$peer_vms"; then
        echo "ABORT: $VM also running on $PEER (split brain?). Refusing to overwrite a live base."
        OVERALL_STATUS=1
        continue
      fi

      # Detect current disk state: flat base, or base+overlay?
      active=$(virsh domblklist "$VM" | awk -v d="$DISK" '$1==d {print $2}')
      if [ -z "$active" ]; then
        echo "ABORT: could not determine active disk for $DISK on $VM"
        OVERALL_STATUS=1
        continue
      fi

      if [ "$active" = "$BASE" ]; then
        echo "Disk is flat ($active); nothing to commit, going straight to split."
      else
        echo "Committing overlay $active down into base..."
        if ! virsh blockcommit "$VM" "$DISK" --active --pivot --wait; then
          echo "ERROR: Blockcommit failed for $VM. Skipping."
          OVERALL_STATUS=1
          continue
        fi
        rm -f "$active"
      fi

      # Re-freeze the now-current base
      if ! virsh snapshot-create-as "$VM" --name "$OVERLAY_NAME" --disk-only --atomic --no-metadata; then
        echo "ERROR: Failed to create snapshot for $VM. Skipping."
        OVERALL_STATUS=1
        continue
      fi

      # Push the frozen base ATOMICALLY
      echo "Syncing base to peer $PEER..."
      if ! scp "$BASE" "root@$PEER:$BASE.tmp"; then
        echo "ERROR: SCP failed for $VM. Skipping."
        OVERALL_STATUS=1
        continue
      fi

      if ! ssh "root@$PEER" "mv -f '$BASE.tmp' '$BASE'"; then
        echo "ERROR: Failed to finalize atomic move on peer for $VM. Skipping."
        OVERALL_STATUS=1
        continue
      fi

      # Stage the peer for migration
      ssh "root@$PEER" "rm -f '$STUB' && \
        qemu-img create -f qcow2 -b '$BASE' -F qcow2 '$STUB' && \
        virsh pool-refresh '$VM' || true"

      echo "Base reseeded, peer staged for migration ($PEER) for $VM."
      echo
    done

    exit $OVERALL_STATUS
  '';
in {
  options.services.qemu-incremental-backup-nightly = {
    enable = mkEnableOption "Nightly QEMU incremental backup script for cluster nodes";

    vms = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of VMs to iterate through for the nightly backup and sync.";
    };

    # NEW OPTION ADDED HERE
    peerIp = mkOption {
      type = types.str;
      description = "The target IP address of the peer node to sync backups to.";
      example = "192.168.1.100";
    };

    calendar = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00";
      description = "Systemd OnCalendar string indicating when to run the script.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.qemu-incremental-backup-nightly = {
      description = "Nightly QEMU Base Sync to Peer Node";
      path = with pkgs; [
        libvirt
        openssh
        gawk
        gnugrep
        util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}/bin/qemu-incremental-backup";
        User = "root";
      };
    };

    systemd.timers.qemu-incremental-backup-nightly = {
      description = "Timer for Nightly QEMU Base Sync";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = true;
      };
    };
  };
}
