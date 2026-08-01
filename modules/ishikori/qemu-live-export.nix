# qemu-live-export.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.qemu-live-export;

  exportScript = pkgs.writeShellApplication {
    name = "qemu-live-export";
    runtimeInputs =
      (with pkgs; [
        libvirt
        qemu-utils # qemu-img
        zstd
        xz
        coreutils
        gawk
        gnugrep
        util-linux # flock
      ])
      ++ [config.boot.zfs.package]; # zfs userland matched to the kernel module

    text = ''
            # ------------------------------------------------------------------
            # Cold / offsite VM export. Standalone: this NEVER touches the live
            # disk chain and shares nothing with the nightly syncoid job.
            #
            # It takes a throwaway ZFS snapshot of the per-VM dataset (freezing
            # base + daily overlay in one instant), flattens the chain into a
            # single qcow2 FROM THE SNAPSHOT, compresses it, and writes an XML +
            # checksum next to it as a self-contained restore bundle.
            #
            # Usage:
            #   sudo vm-cold-export                # export every configured VM
            #   sudo vm-cold-export caddy pihole   # export just these
            # ------------------------------------------------------------------

            if [ "$(id -u)" -ne 0 ]; then
              echo "vm-cold-export must run as root (zfs / virsh / qemu-img on system images)."
              echo "Try: sudo vm-cold-export ..."
              exit 1
            fi

            # Config-baked defaults (Nix -> bash). escapeShellArgs already emits a
            # quoted list, so this is a plain array literal -- no eval needed.
            DEFAULT_VMS=(${escapeShellArgs cfg.vms})
            PARENT="${cfg.datasetParent}"
            OUTDIR="${cfg.outputDir}"
            DISK="${cfg.disk}"
            COMPRESSOR="${cfg.compressor}"      # zstd | xz | qcow2-zstd
            ZSTD_LEVEL="${toString cfg.zstdLevel}"
            ZSTD_LONG="${cfg.zstdLong}"         # e.g. "--long=31" or "--ultra --long=31"
            DO_FREEZE="${boolToString cfg.fsFreeze}"

            # CLI args override the configured default list.
            if [ "$#" -gt 0 ]; then
              VMS=("$@")
            else
              VMS=("''${DEFAULT_VMS[@]}")
            fi

            if [ "''${#VMS[@]}" -eq 0 ]; then
              echo "No VMs specified (none on the command line and programs.qemu-cold-export.vms is empty)."
              exit 1
            fi

            mkdir -p "$OUTDIR"

            # Serialize cold exports against each other. Intentionally a DIFFERENT
            # lock from the nightly job -- the ZFS snapshot isolates us, so the two
            # are free to overlap.
            exec 8>/tmp/vm-cold-export.lock
            flock -n 8 || { echo "another cold export is in progress; skipping"; exit 0; }

            OVERALL_STATUS=0

            # Per-VM cleanup state so a mid-run failure never leaves a guest frozen
            # or a stray snapshot / tempdir behind.
            CUR_FROZEN_VM=""
            CUR_SNAP=""
            CUR_TMP=""

            reset_vm_state() {
              # Thaw first -- a dangling fsfreeze hangs guest I/O.
              [ -n "$CUR_FROZEN_VM" ] && { virsh domfsthaw "$CUR_FROZEN_VM" >/dev/null 2>&1 || true; CUR_FROZEN_VM=""; }
              [ -n "$CUR_SNAP" ]      && { zfs destroy "$CUR_SNAP" >/dev/null 2>&1 || true; CUR_SNAP=""; }
              [ -n "$CUR_TMP" ] && [ -d "$CUR_TMP" ] && { rm -rf "$CUR_TMP"; CUR_TMP=""; }
              return 0
            }
            trap reset_vm_state EXIT

            for VM in "''${VMS[@]}"; do
              echo "=================================================="
              echo "Cold export: $VM"
              echo "=================================================="

              DATASET="$PARENT/$VM"
              IMGDIR="/var/lib/libvirt/images/$VM"
              BASE="$IMGDIR/$VM.qcow2"

              # Must be a domain this node knows about (running or shut off).
              if ! virsh dominfo "$VM" >/dev/null 2>&1; then
                echo "  $VM is not defined on this node; skipping. (Run the export on whichever node hosts it.)"
                continue
              fi

              # Must have a dataset to snapshot.
              if ! zfs list -H -o name "$DATASET" >/dev/null 2>&1; then
                echo "  ERROR: dataset $DATASET does not exist; cannot snapshot $VM. Skipping."
                OVERALL_STATUS=1
                continue
              fi

              # Resolve the active disk. domblklist shows the live path if running,
              # otherwise the persistent-config path. dominfo already passed, so
              # domblklist should succeed; guard the substitution anyway.
              active=$(virsh domblklist "$VM" | awk -v d="$DISK" '$1==d {print $2}') || true
              if [ -z "$active" ]; then
                echo "  ERROR: could not find disk '$DISK' on $VM. Skipping."
                OVERALL_STATUS=1
                continue
              fi

              # Chain-depth guard: handle exactly "flat base" or "base + one
              # overlay" (the steady state the nightly job leaves). Deeper means
              # extra snapshots were left around -- bail loudly.
              chain_len=$(qemu-img info -U --backing-chain --output=json "$active" | grep -c '"filename"' || true)
              if [ "$chain_len" -gt 2 ]; then
                echo "  ERROR: $DISK on $VM has a $chain_len-deep backing chain."
                echo "         Expected base or base+overlay. Consolidate first, then re-run."
                echo "Consider running sudo virsh blockcommit $VM vda --active --pivot --verbose"
                OVERALL_STATUS=1
                continue
              fi

              running=0
              if virsh list --state-running --name | grep -qx "$VM"; then
                running=1
              fi

            SNAPNAME="coldbak-$(date +%Y-%m-%d_%Hh%Mm%Ss)"
              SNAP="$DATASET@$SNAPNAME"
              TS="$(date +%Y-%m-%d_%Hh%Mm%Ss)"
              OUT="$OUTDIR/$VM-$TS"
              mkdir -p "$OUT"

              # ---- freeze (best effort) + snapshot + immediate thaw ----
              if [ "$running" -eq 1 ] && [ "$DO_FREEZE" = "true" ]; then
                if virsh domfsfreeze "$VM" >/dev/null 2>&1; then
                  CUR_FROZEN_VM="$VM"
                  echo "  Guest filesystems frozen."
                else
                  echo "  NOTE: fsfreeze failed (guest agent missing?); snapshot will be crash-consistent."
                fi
              fi

              if ! zfs snapshot "$SNAP"; then
                echo "  ERROR: zfs snapshot $SNAP failed for $VM. Skipping."
                OVERALL_STATUS=1
                reset_vm_state
                continue
              fi
              CUR_SNAP="$SNAP"

              [ -n "$CUR_FROZEN_VM" ] && { virsh domfsthaw "$VM" >/dev/null 2>&1 || true; CUR_FROZEN_VM=""; echo "  Guest filesystems thawed (snapshot already captured)."; }

              # ---- locate the frozen files inside the snapshot ----
              SNAPDIR="$IMGDIR/.zfs/snapshot/$SNAPNAME"
              snap_base="$SNAPDIR/$(basename "$BASE")"
              snap_active="$SNAPDIR/$(basename "$active")"

              if [ ! -f "$snap_base" ]; then
                echo "  ERROR: base $snap_base not found in snapshot for $VM. Skipping."
                OVERALL_STATUS=1
                reset_vm_state
                continue
              fi

              CUR_TMP="$(mktemp -d)"
              FLAT="$CUR_TMP/$VM.qcow2"

              # ---- decide the convert source ----
              if [ "$active" = "$BASE" ]; then
                echo "  Disk is flat; flattening base directly."
                SRC="$snap_base"
              else
                if [ ! -f "$snap_active" ]; then
                  echo "  ERROR: overlay $snap_active not found in snapshot for $VM. Skipping."
                  OVERALL_STATUS=1
                  reset_vm_state
                  continue
                fi
                echo "  Merging overlay $(basename "$active") into base..."
                # Copy the (small) overlay out and re-point its backing file at the
                # FROZEN base inside the snapshot. -u is a metadata-only rebase:
                # same data, just correcting the recorded path so convert reads a
                # consistent frozen pair instead of the live base.
                cp "$snap_active" "$CUR_TMP/overlay.qcow2" \
                  || { echo "  ERROR: could not copy overlay for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                chmod u+w "$CUR_TMP/overlay.qcow2"
                qemu-img rebase -u -b "$snap_base" -F qcow2 "$CUR_TMP/overlay.qcow2" \
                  || { echo "  ERROR: rebase failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                SRC="$CUR_TMP/overlay.qcow2"
              fi


      # ---- flatten + compress ----
              case "$COMPRESSOR" in
                qcow2-zstd)
                  FINAL="$OUT/$VM.qcow2"
                  echo "  Flattening -> compressed qcow2 (internal zstd, still bootable)..."
                  qemu-img convert -p -O qcow2 -c -o compression_type=zstd "$SRC" "$FINAL" \
                    || { echo "  ERROR: convert failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                  ;;
                zstd)
                  echo "  Flattening (sparse) before compression..."
                  qemu-img convert -p -O qcow2 "$SRC" "$FLAT" \
                    || { echo "  ERROR: flatten failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                  echo "  Compressing with zstd -$ZSTD_LEVEL $ZSTD_LONG ..."
                  FINAL="$OUT/$VM.qcow2.zst"
                  # shellcheck disable=SC2086
                  zstd -v -T0 $ZSTD_LONG "-$ZSTD_LEVEL" "$FLAT" -o "$FINAL" \
                    || { echo "  ERROR: zstd failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                  ;;
                xz)
                  echo "  Flattening (sparse) before compression..."
                  qemu-img convert -p -O qcow2 "$SRC" "$FLAT" \
                    || { echo "  ERROR: flatten failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                  echo "  Compressing with xz -9e (smallest, slowest)..."
                  FINAL="$OUT/$VM.qcow2.xz"
                  xz -v -9e -T0 -c "$FLAT" > "$FINAL" \
                    || { echo "  ERROR: xz failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }
                  ;;
                *)
                  echo "  ERROR: unknown compressor '$COMPRESSOR' for $VM. Skipping."
                  OVERALL_STATUS=1
                  reset_vm_state
                  continue
                  ;;
              esac
              # ---- restore bundle: domain XML + checksums ----
              virsh dumpxml --inactive --security-info "$VM" > "$OUT/$VM.xml" \
                || { echo "  ERROR: could not dump XML for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }

              ( cd "$OUT" && sha256sum "$(basename "$FINAL")" "$VM.xml" > SHA256SUMS ) \
                || { echo "  ERROR: checksum step failed for $VM."; OVERALL_STATUS=1; reset_vm_state; continue; }

              size=$(du -h "$FINAL" | cut -f1)
              reset_vm_state
              echo "  DONE: $FINAL ($size)"
              echo "        bundle: $OUT  (image + $VM.xml + SHA256SUMS)"
              echo
            done

            echo "All requested exports processed. Upload the per-VM folders in $OUTDIR"
            echo "to your NFS share / Google Drive (rclone) at your leisure."
            exit $OVERALL_STATUS
    '';
  };
in {
  options.programs.qemu-live-export = {
    enable = mkEnableOption "On-demand cold/offsite VM export (flatten + compress to a single file)";

    vms = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Default VMs to export when 'vm-cold-export' is run with no arguments. CLI args override this.";
    };

    datasetParent = mkOption {
      type = types.str;
      default = "vmpool/images";
      description = "Parent ZFS dataset holding one child dataset per VM (e.g. vmpool/images/caddy).";
    };

    outputDir = mkOption {
      type = types.str;
      default = "/var/lib/libvirt/cold-export";
      description = "Where export bundles are written. Point this at an NFS mount or an rclone/gdrive staging dir.";
    };

    disk = mkOption {
      type = types.str;
      default = "vda";
      description = "Target block device name inside the guest to export (as shown by 'virsh domblklist').";
    };

    compressor = mkOption {
      type = types.enum ["zstd" "xz" "qcow2-zstd"];
      default = "zstd";
      description = ''
        How to compress the flattened image:
          zstd        - flatten (sparse) then whole-file zstd. Best size/speed balance. (default)
          xz          - flatten then xz -9e. Smallest, much slower, slow to decompress.
          qcow2-zstd  - flatten straight into a still-bootable zstd qcow2. Larger, most convenient.
      '';
    };

    zstdLevel = mkOption {
      type = types.int;
      default = 19;
      description = "zstd level (compressor = zstd only). 19 is a strong default; 22 needs '--ultra' added to zstdLong and gives a marginal size win for a lot more CPU.";
    };

    zstdLong = mkOption {
      type = types.str;
      default = "--long=31";
      description = "Extra zstd flags for long-range matching. Set to '--ultra --long=31' if you also raise zstdLevel to 22.";
    };

    fsFreeze = mkOption {
      type = types.bool;
      default = true;
      description = "Try 'virsh domfsfreeze' around the snapshot for filesystem-consistent images (needs qemu-guest-agent in the guest). Falls back to crash-consistent if unavailable.";
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      default = exportScript;
      description = "The cold-export script package, for use by other modules.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [exportScript];
  };
}
