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
    XMLBAK="/var/lib/libvirt/onboard-xml"

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

      # Detect the active disk FIRST: the onboarding decision is based on
      # where the disk actually lives, not just whether the dataset exists.
      src=$(virsh domblklist "$VM" | awk -v d="$DISK" '$1==d {print $2}')
      if [ -z "$src" ]; then
        echo "ABORT: could not determine active disk for $DISK on $VM"
        OVERALL_STATUS=1
        continue
      fi

      # GUARD 2 / ONBOARDING: the VM runs here, so its disk SHOULD live
      # inside $IMGDIR (the per-VM dataset mountpoint). If it doesn't --
      # whether the dataset is missing entirely (brand-new VM) or exists but
      # the disk was never moved into it -- onboard it: create the dataset
      # if needed, live-copy the disk into it (blockcopy flattens any chain
      # into a single base image), then fall through to the normal
      # commit/split flow below, which sees a flat disk and splits it.
      case "$src" in
        "$IMGDIR"/*) IN_DATASET=1 ;;
        *)           IN_DATASET=0 ;;
      esac

      if [ "$IN_DATASET" -eq 0 ]; then
        echo "Disk for $VM is at $src (outside $IMGDIR); onboarding..."

        if ! zfs list -H -o name "$DATASET" >/dev/null 2>&1; then
          # If the target directory already holds files (e.g. a plain dir on
          # the parent dataset), move it aside so the dataset can mount there
          # cleanly. The rename does not disturb the running guest: qemu
          # holds an open fd.
          if [ -e "$IMGDIR" ]; then
            STASH="$IMGDIR.pre-zfs.$(date +%s)"
            echo "Moving existing $IMGDIR aside to $STASH"
            mv "$IMGDIR" "$STASH"
          fi

          if ! zfs create "$DATASET"; then
            echo "ABORT: failed to create dataset $DATASET for $VM."
            OVERALL_STATUS=1
            continue
          fi
        fi

        # Make sure the dataset is mounted where libvirt expects the disk.
        mp=$(zfs get -H -o value mountpoint "$DATASET")
        if [ "$mp" != "$IMGDIR" ]; then
          zfs set mountpoint="$IMGDIR" "$DATASET"
        fi
        zfs mount "$DATASET" 2>/dev/null || true

        # blockcopy only works on TRANSIENT domains, so: backup XML ->
        # undefine (VM keeps running) -> blockcopy+pivot -> re-define.
        # On success we re-define from the LIVE post-pivot XML so the
        # persistent config points at the new disk path inside the dataset.
        mkdir -p "$XMLBAK"
        virsh dumpxml --inactive --security-info "$VM" > "$XMLBAK/$VM.xml"
        virsh undefine "$VM"

        if virsh blockcopy "$VM" "$DISK" --dest "$BASE" --format qcow2 --wait --pivot; then
          virsh dumpxml --security-info "$VM" > "$XMLBAK/$VM.live.xml"
          virsh define "$XMLBAK/$VM.live.xml"
          echo "Onboarded $VM onto $DATASET (disk now at $BASE)."
          echo "  NOTE: old image at $src (and any $IMGDIR.pre-zfs.* stash) can be deleted after verification."
        else
          echo "ERROR: blockcopy failed for $VM; restoring original definition and skipping."
          virsh define "$XMLBAK/$VM.xml"
          OVERALL_STATUS=1
          continue
        fi
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
          coreutils
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
