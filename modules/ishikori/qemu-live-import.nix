# qemu-live-import.nix
#
# The inverse of qemu-live-export: consumes a cold-export bundle and rebuilds a
# usable VM disk in a directory you choose. Standalone; touches no ZFS datasets.
#
# A bundle (as produced by the exporter) is a folder containing:
#     <vm>.qcow2 | <vm>.qcow2.zst | <vm>.qcow2.xz    the flattened disk
#     <vm>.xml                                        inactive domain definition
#     SHA256SUMS                                      integrity manifest
#
# What it does, in order:
#   1. locate the image + xml + checksums (accepts a bundle DIR or a bare image)
#   2. verify SHA256SUMS first -- refuse to import anything corrupt
#   3. inflate into DEST/<vm>.qcow2 via a .partial temp:
#        .zst -> zstd -d ,  .xz -> xz -d ,  .qcow2 -> qemu-img convert (de-compress)
#   4. qemu-img check the result, then publish it with an atomic mv
#   5. (-D) rewrite the disk's <source file> to the new path and `virsh define`
#
# Safety: runs as root; refuses to overwrite an existing image without -f; and
# refuses outright if a domain of that name is currently RUNNING here.
#
# Usage:
#   sudo qemu-live-import /mnt/nfs/vmbackups/caddy-20260801-030102
#   sudo qemu-live-import -d /var/lib/libvirt/images/caddy -D  <bundle>
#   sudo qemu-live-import -n caddy2 -d /tank/scratch  <bundle>     # restore under a new name/dir
#
# NOTE on -D: it defines with the ORIGINAL name/UUID/MAC (disaster-recovery
# semantics). To run a second copy alongside the original, restore the disk
# without -D and hand-edit name/UUID/MAC before defining.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.qemu-live-import;

  importScript = pkgs.writeShellApplication {
    name = "qemu-live-import";
    runtimeInputs = with pkgs; [
      libvirt # virsh
      qemu-utils # qemu-img
      libxml2 # xmllint (disk-path xpath)
      zstd
      xz
      coreutils
      gawk
      gnugrep
    ];

    text = ''
      # defaults (overridable by flags)
      DEST="${cfg.defaultOutputDir}"
      DISK="${cfg.disk}"
      NAME=""
      DO_DEFINE=0
      FORCE=0

      usage() {
        cat <<EOF
      Usage: qemu-live-import [options] <bundle-dir | image-file>
        Restores a cold-export bundle: verifies checksums, inflates the compressed
        disk into a chosen directory, and (optionally) re-defines the domain.

        -d DIR   directory to create the disk in (default: $DEST) -> writes DIR/<vm>.qcow2
        -n NAME  override the VM/disk name (default: derived from the image filename)
        -D       define the domain from the bundle's XML (rewrites the disk path)
        -f       overwrite an existing destination image
        -h       this help
      EOF
      }

      while getopts "d:n:Dfh" opt; do
        case "$opt" in
          d) DEST="$OPTARG" ;;
          n) NAME="$OPTARG" ;;
          D) DO_DEFINE=1 ;;
          f) FORCE=1 ;;
          h) usage; exit 0 ;;
          \?) echo "bad option; -h for help" >&2; exit 1 ;;
        esac
      done
      shift $((OPTIND - 1))

      if [ "$(id -u)" -ne 0 ]; then
        echo "qemu-live-import must run as root (writes system images / virsh define)." >&2
        echo "Try: sudo qemu-live-import ..." >&2
        exit 1
      fi

      if [ "$#" -lt 1 ]; then
        echo "No bundle given. Pass an export folder or an image file. -h for help." >&2
        exit 1
      fi
      BUNDLE="$1"

      # ---- locate image + xml + checksums ----
      IMG=""; XML=""; SUMS=""
      if [ -d "$BUNDLE" ]; then
        for cand in "$BUNDLE"/*.qcow2.zst "$BUNDLE"/*.qcow2.xz "$BUNDLE"/*.qcow2; do
          [ -f "$cand" ] || continue
          IMG="$cand"; break
        done
        [ -f "$BUNDLE/SHA256SUMS" ] && SUMS="$BUNDLE/SHA256SUMS"
        for x in "$BUNDLE"/*.xml; do [ -f "$x" ] && { XML="$x"; break; }; done
      elif [ -f "$BUNDLE" ]; then
        IMG="$BUNDLE"
        bdir="$(dirname "$BUNDLE")"
        [ -f "$bdir/SHA256SUMS" ] && SUMS="$bdir/SHA256SUMS"
      else
        echo "ERROR: $BUNDLE is neither a directory nor a file." >&2
        exit 1
      fi

      if [ -z "$IMG" ]; then
        echo "ERROR: no qcow2 image (.qcow2/.qcow2.zst/.qcow2.xz) found in $BUNDLE." >&2
        exit 1
      fi

      # ---- derive VM name from the image filename unless overridden ----
      if [ -z "$NAME" ]; then
        base="$(basename "$IMG")"
        NAME="''${base%.qcow2*}"
      fi
      echo "VM name: $NAME"
      echo "Image:   $IMG"
      [ -n "$XML" ] && echo "XML:     $XML"

      # ---- verify integrity before doing anything destructive ----
      if [ -n "$SUMS" ]; then
        echo "Verifying SHA256SUMS..."
        if ! ( cd "$(dirname "$SUMS")" && sha256sum -c "$(basename "$SUMS")" ); then
          echo "ERROR: checksum verification failed. Refusing to import a corrupt bundle." >&2
          exit 1
        fi
      else
        echo "NOTE: no SHA256SUMS found; skipping integrity check."
      fi

      # ---- destination + safety guards ----
      mkdir -p "$DEST"
      OUT="$DEST/$NAME.qcow2"

      if virsh list --state-running --name 2>/dev/null | grep -qx "$NAME"; then
        echo "ERROR: a domain named $NAME is RUNNING here. Stop/migrate it before importing over its disk." >&2
        exit 1
      fi
      if [ -e "$OUT" ] && [ "$FORCE" -ne 1 ]; then
        echo "ERROR: $OUT already exists. Use -f to overwrite (do not clobber a live disk)." >&2
        exit 1
      fi

      # ---- inflate / normalize into place (via a .partial temp so a failure
      #      never leaves a half-written disk at the real path) ----
      tmpout="$DEST/.$NAME.qcow2.partial"
      rm -f "$tmpout"
      case "$IMG" in
        *.qcow2.zst)
          echo "Decompressing zstd..."
          # --long=31 re-enables the long-range match window the exporter used.
          # zstd caps the decode window at 128 MiB by default as an anti-DoS guard;
          # without this it refuses frames built with --long (window > 128 MiB).
          zstd -d --long=31 -f "$IMG" -o "$tmpout"
          ;;
        *.qcow2.xz)
          echo "Decompressing xz..."
          xz -dc "$IMG" > "$tmpout"
          ;;
        *.qcow2)
          echo "Normalizing qcow2 (inflating any internal compression)..."
          qemu-img convert -O qcow2 "$IMG" "$tmpout"
          ;;
        *)
          echo "ERROR: unrecognized image extension: $IMG" >&2
          rm -f "$tmpout"
          exit 1
          ;;
      esac

      # ---- validate the result before publishing it ----
      if ! qemu-img check "$tmpout"; then
        echo "ERROR: qemu-img check failed. Leaving $tmpout for inspection." >&2
        exit 1
      fi
      mv -f "$tmpout" "$OUT"
      echo "Disk ready: $OUT ($(du -h "$OUT" | cut -f1))"

      # ---- optional: re-define the domain, repointing the disk at $OUT ----
      if [ "$DO_DEFINE" -eq 1 ]; then
        if [ -z "$XML" ]; then
          echo "WARNING: -D given but no domain XML in the bundle; skipping define." >&2
        else
          OLDPATH="$(xmllint --xpath "string(//devices/disk[target/@dev='$DISK']/source/@file)" "$XML" 2>/dev/null || true)"
          tmpxml="$(mktemp)"
          if [ -n "$OLDPATH" ] && [ "$OLDPATH" != "$OUT" ]; then
            echo "Repointing $DISK: $OLDPATH -> $OUT"
            # fixed-string (not regex) replace, so odd path chars can't misfire
            awk -v old="$OLDPATH" -v new="$OUT" '
              { i = index($0, old); if (i > 0) { $0 = substr($0,1,i-1) new substr($0, i+length(old)) } print }
            ' "$XML" > "$tmpxml"
          else
            cp "$XML" "$tmpxml"
          fi
          echo "Defining $NAME (name/UUID/MAC preserved -- disaster-recovery restore, not a clone)..."
          if virsh define "$tmpxml"; then
            echo "Defined. Start it with: virsh start $NAME"
          else
            echo "ERROR: virsh define failed; edited XML left at $tmpxml" >&2
            exit 1
          fi
          rm -f "$tmpxml"
        fi
      else
        echo
        echo "Not defining a domain (pass -D to define from the bundle XML)."
        echo "If wiring it up by hand, point your domain's $DISK <source file> at: $OUT"
      fi
    '';
  };
in {
  options.programs.qemu-live-import = {
    enable = mkEnableOption "On-demand restore of a cold-export bundle into a chosen directory";

    defaultOutputDir = mkOption {
      type = types.str;
      default = "/var/lib/libvirt/images";
      description = "Default directory the restored <vm>.qcow2 is written to. Overridable per-run with -d.";
    };

    disk = mkOption {
      type = types.str;
      default = "vda";
      description = "Target block device name in the domain XML whose <source file> is repointed on -D define.";
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      default = importScript;
      description = "The import script package, for use by other modules.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [importScript];
  };
}
