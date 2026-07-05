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

    # Securely map the Nix lists to bash arrays
    eval "VMS=(${escapeShellArgs cfg.vms})"
    eval "PEERS=(${escapeShellArgs cfg.peerIps})"

    OVERLAY_NAME="daily"
    DISK="vda"
    PARENT="${cfg.datasetParent}"

    # Global lock prevents cron overlaps if a sync takes longer than 24h
    exec 9>/tmp/pelican-daily.lock
    flock -n 9 || { echo "another run in progress; skipping"; exit 0; }

    OVERALL_STATUS=0

    for VM in "''${VMS[@]}"; do
      echo "=================================================="
      echo "Starting backup cycle for VM: $VM"
      echo "=================================================="

      DATASET="$PARENT/$VM"
      IMGDIR="/var/lib/libvirt/images/$VM"
      BASE="$IMGDIR/$VM.qcow2"

      # GUARD 1 (source): only proceed if the VM is live HERE.
      # This is what makes replication direction follow the VM around:
      # whichever node currently runs it becomes tonight's send side.
      # VMs hosted on the peer are a clean skip, NOT an error.
      if ! virsh list --state-running --name | grep -qx "$VM"; then
        if virsh dominfo "$VM" >/dev/null 2>&1; then
          echo "$VM is defined here but not running (shut off?); not the source tonight. Skipping."
          echo "  NOTE: if it's not running on any peer either, nothing is backing it up."
        else
          echo "$VM not defined here (migrated away); not the source tonight. Skipping."
        fi
        continue
      fi

      # GUARD 2: the VM runs here, so its dataset MUST exist.
      # If this fires, a live VM is outside the replication scheme.
      if ! zfs list -H -o name "$DATASET" >/dev/null 2>&1; then
        echo "ABORT: $VM is running here but ZFS dataset $DATASET does not exist."
        echo "       Restructure it into its own child dataset first."
        OVERALL_STATUS=1
        continue
      fi

      # GUARD 3 (dest): Loop through ALL peers to ensure safe state
      for PEER in "''${PEERS[@]}"; do
        if ! peer_vms=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "root@$PEER" \
              "virsh list --state-running --name" 2>&1); then
          echo "ABORT: cannot verify peer state ($PEER unreachable) for $VM: $peer_vms"
          OVERALL_STATUS=1
          continue 2
        fi

        if grep -qx "$VM" <<< "$peer_vms"; then
          echo "ABORT: $VM also running on $PEER (split brain?). Refusing to replicate over a live base."
          OVERALL_STATUS=1
          continue 2
        fi
      done

      # Detect current disk state
      active=$(virsh domblklist "$VM" | awk -v d="$DISK" '$1==d {print $2}')
      if [ -z "$active" ]; then
        echo "ABORT: could not determine active disk for $DISK on $VM"
        OVERALL_STATUS=1
        continue
      fi

      # Commit local data
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

      # Re-freeze the now-current base with a fresh overlay.
      # IMPORTANT: this happens BEFORE the ZFS snapshot so the base file is
      # completely static inside the snapshot, and the snapshot also captures
      # the fresh (near-empty) overlay. Replication therefore delivers a
      # fully-staged migration target: identical base + matching stub, no
      # peer-side qemu-img staging needed.
      if ! virsh snapshot-create-as "$VM" --name "$OVERLAY_NAME" --disk-only --atomic --no-metadata; then
        echo "ERROR: Failed to create snapshot for $VM. Skipping."
        OVERALL_STATUS=1
        continue
      fi

      # MULTI-NODE SYNC: incrementally replicate the dataset to every peer.
      # syncoid creates its own sync snapshot, finds the newest common
      # snapshot with the peer, rolls the peer back to it (recv -F) if the
      # peer has diverged (e.g. the VM ran there last week), and sends only
      # the changed blocks (--no-stream: direct incremental, no intermediate
      # snapshot replay). Every prior snapshot is a rollback point.
      for PEER in "''${PEERS[@]}"; do
        echo "Replicating $DATASET to $PEER..."
        if ! syncoid --identifier=nightly --compress=none --no-stream \
              "$DATASET" "root@$PEER:$DATASET"; then
          echo "ERROR: syncoid replication of $VM to $PEER failed."
          OVERALL_STATUS=1
          continue
        fi

        # Nudge libvirt on the peer so it sees the refreshed files
        ssh "root@$PEER" "virsh pool-refresh '$VM' >/dev/null 2>&1 || virsh pool-refresh default >/dev/null 2>&1 || true"

        echo "Dataset replicated; $PEER is staged for --copy-storage-inc migration of $VM."
      done

      echo "Finished processing $VM."
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

    peerIps = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of target IP addresses of the peer nodes to sync backups to. Do NOT include this node's own IP.";
      example = ["192.168.1.99"];
    };

    datasetParent = mkOption {
      type = types.str;
      default = "vmpool/images";
      description = "Parent ZFS dataset containing one child dataset per VM (e.g. vmpool/images/caddy). Must exist under the same name on all peers.";
    };

    calendar = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00";
      description = "Systemd OnCalendar string indicating when to run the script.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.qemu-incremental-backup-nightly = {
      description = "Nightly QEMU Base Snapshot + ZFS Replication to Peer Nodes";
      path = with pkgs;
        [
          libvirt
          openssh
          gawk
          gnugrep
          util-linux
          sanoid # provides the syncoid binary
          pv
          mbuffer
          lzop
          zstd
          procps
        ]
        ++ [config.boot.zfs.package];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}/bin/qemu-incremental-backup";
        User = "root";
      };
    };

    systemd.timers.qemu-incremental-backup-nightly = {
      description = "Timer for Nightly QEMU Base Snapshot + ZFS Replication";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = true;
      };
    };
  };
}
