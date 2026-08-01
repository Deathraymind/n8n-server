# vm-restic-backup.nix
#
# Incremental offsite VM backup with restic. For each VM it snapshots the
# dataset (fsfreeze best-effort), flattens the chain into an UNCOMPRESSED
# qcow2 in a scratch dir, then `restic backup`s the scratch dir to R2 and
# `restic forget --prune`s by policy. restic does the dedup, compression,
# and client-side encryption, so this replaces the zstd + rclone-crypt +
# lifecycle steps in one shot.
#
# Uncompressed on purpose: compression kills restic's chunk dedup. qcow2
# (not raw) so a restored file drops straight into qemu-live-import.
#
# Secrets live OUTSIDE the Nix store:
#   $PASSFILE  restic repo password (one line)         chmod 600
#   $ENVFILE   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for R2   chmod 600
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.vm-restic-backup;
  resticScript = pkgs.writeShellApplication {
    name = "vm-restic-backup";
    runtimeInputs = with pkgs;
      [libvirt qemu-utils restic coreutils gawk gnugrep util-linux]
      ++ [config.boot.zfs.package];
    text = ''
      VMS=(${escapeShellArgs cfg.vms})
      PARENT="${cfg.datasetParent}"
      DISK="${cfg.disk}"
      STAGING="${cfg.stagingDir}"
      REPO="${cfg.repository}"
      PASSFILE="${cfg.passwordFile}"
      ENVFILE="${cfg.environmentFile}"
      KEEP_DAILY=${toString cfg.keepDaily}
      KEEP_WEEKLY=${toString cfg.keepWeekly}
      KEEP_MONTHLY=${toString cfg.keepMonthly}
      DO_FREEZE=${boolToString cfg.fsFreeze}

      case "''${1:-}" in -h|--help) echo "Usage: vm-restic-backup [vm ...]   (no args = configured VMs)"; exit 0;; esac
      if [ "$#" -gt 0 ]; then VMS=("$@"); fi
      if [ "''${#VMS[@]}" -eq 0 ]; then echo "no VMs configured or given" >&2; exit 1; fi

      if [ "$(id -u)" -ne 0 ]; then echo "run as root: sudo vm-restic-backup ..." >&2; exit 1; fi
      [ -f "$PASSFILE" ] || { echo "missing restic password file: $PASSFILE" >&2; exit 1; }
      [ -f "$ENVFILE" ]  || { echo "missing R2 env file: $ENVFILE" >&2; exit 1; }

      export RESTIC_REPOSITORY="$REPO"
      export RESTIC_PASSWORD_FILE="$PASSFILE"
      set -a
      # shellcheck disable=SC1090
      . "$ENVFILE"
      set +a

      exec 8>/tmp/vm-restic.lock
      flock -n 8 || { echo "another restic run in progress; skipping"; exit 0; }

      # init the repo on first use
      restic snapshots >/dev/null 2>&1 || { echo "initializing restic repo..."; restic init; }

      mkdir -p "$STAGING"
      rm -rf "''${STAGING:?}/"*

      CUR_FROZEN=""; CUR_SNAP=""
      cleanup() {
        [ -n "$CUR_FROZEN" ] && { virsh domfsthaw "$CUR_FROZEN" >/dev/null 2>&1 || true; CUR_FROZEN=""; }
        [ -n "$CUR_SNAP" ] && { zfs destroy "$CUR_SNAP" >/dev/null 2>&1 || true; CUR_SNAP=""; }
        return 0
      }
      trap cleanup EXIT

      STATUS=0
      for VM in "''${VMS[@]}"; do
        echo "== staging $VM =="
        DATASET="$PARENT/$VM"
        IMGDIR="/var/lib/libvirt/images/$VM"
        BASE="$IMGDIR/$VM.qcow2"

        virsh dominfo "$VM" >/dev/null 2>&1 || { echo "  not defined here; skip"; continue; }
        zfs list -H -o name "$DATASET" >/dev/null 2>&1 || { echo "  no dataset $DATASET; skip"; STATUS=1; continue; }

        active=$(virsh domblklist "$VM" | awk -v d="$DISK" '$1==d {print $2}') || true
        [ -n "$active" ] || { echo "  no disk $DISK; skip"; STATUS=1; continue; }

        SNAP="$DATASET@restic-$(date +%s)"
        SNAPNAME="''${SNAP##*@}"

        if [ "$DO_FREEZE" = "true" ] && virsh list --state-running --name | grep -qx "$VM"; then
          if virsh domfsfreeze "$VM" >/dev/null 2>&1; then CUR_FROZEN="$VM"; else echo "  fsfreeze unavailable; crash-consistent"; fi
        fi
        if ! zfs snapshot "$SNAP"; then echo "  snapshot failed"; STATUS=1; cleanup; continue; fi
        CUR_SNAP="$SNAP"
        [ -n "$CUR_FROZEN" ] && { virsh domfsthaw "$VM" >/dev/null 2>&1 || true; CUR_FROZEN=""; }

        SNAPDIR="$IMGDIR/.zfs/snapshot/$SNAPNAME"
        snap_base="$SNAPDIR/$(basename "$BASE")"
        snap_active="$SNAPDIR/$(basename "$active")"
        OUT="$STAGING/$VM.qcow2"

        if [ "$active" = "$BASE" ]; then
          SRC="$snap_base"
        else
          cp "$snap_active" "$STAGING/$VM.overlay"
          chmod u+w "$STAGING/$VM.overlay"
          if ! qemu-img rebase -u -b "$snap_base" -F qcow2 "$STAGING/$VM.overlay"; then echo "  rebase failed"; STATUS=1; cleanup; continue; fi
          SRC="$STAGING/$VM.overlay"
        fi

        if ! qemu-img convert -O qcow2 "$SRC" "$OUT"; then echo "  convert failed"; STATUS=1; cleanup; continue; fi
        rm -f "$STAGING/$VM.overlay"
        virsh dumpxml --inactive --security-info "$VM" > "$STAGING/$VM.xml" || true

        cleanup
      done

      echo "== restic backup =="
      restic backup "$STAGING" --tag vm-backup || STATUS=1

      echo "== restic forget --prune =="
      restic forget --tag vm-backup --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --prune || STATUS=1

      rm -rf "''${STAGING:?}/"*
      echo "done (status $STATUS)"
      exit "$STATUS"
    '';
  };
in {
  options.programs.vm-restic-backup = {
    enable = mkEnableOption "Incremental restic VM backup to R2 (flatten uncompressed, dedup, prune)";
    vms = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "VMs to back up when run with no args. CLI args override.";
    };
    datasetParent = mkOption {
      type = types.str;
      default = "vmpool/images";
      description = "Parent ZFS dataset (one child per VM).";
    };
    disk = mkOption {
      type = types.str;
      default = "vda";
      description = "Guest disk device to flatten.";
    };
    stagingDir = mkOption {
      type = types.str;
      default = "/var/lib/vm-restic-staging";
      description = "Scratch dir for the uncompressed staged images. Needs room for one full set; wiped each run.";
    };
    repository = mkOption {
      type = types.str;
      default = "s3:https://ACCOUNTID.r2.cloudflarestorage.com/hypervisor-backups/restic";
      description = "restic repository URL (R2 via the s3: backend). Put your real account id + bucket here.";
    };
    passwordFile = mkOption {
      type = types.str;
      default = "/etc/restic/vm-repo.pass";
      description = "File with the restic repo password (one line). 0600, root-owned. NOT in the Nix store.";
    };
    environmentFile = mkOption {
      type = types.str;
      default = "/etc/restic/r2.env";
      description = "File exporting AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for R2. 0600, root-owned.";
    };
    keepDaily = mkOption {
      type = types.int;
      default = 7;
      description = "restic forget --keep-daily.";
    };
    keepWeekly = mkOption {
      type = types.int;
      default = 4;
      description = "restic forget --keep-weekly.";
    };
    keepMonthly = mkOption {
      type = types.int;
      default = 6;
      description = "restic forget --keep-monthly.";
    };
    fsFreeze = mkOption {
      type = types.bool;
      default = true;
      description = "Try guest-agent fsfreeze for application-consistent snapshots (falls back to crash-consistent).";
    };
    package = mkOption {
      type = types.package;
      readOnly = true;
      default = resticScript;
      description = "The restic backup script package, for use by other modules (e.g. a timer).";
    };
  };
  config = mkIf cfg.enable {environment.systemPackages = [resticScript];};
}
