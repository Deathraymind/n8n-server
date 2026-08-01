# vm-backup-push.nix
#
# Encrypt (rclone crypt) + copy cold-export bundles to Cloudflare R2.
# copy-only: never deletes remote objects. Secrets live in the rclone
# config file (NOT the Nix store) -- make it once with `rclone config`.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.vm-backup-push;
  pushScript = pkgs.writeShellApplication {
    name = "vm-backup-push";
    runtimeInputs = with pkgs; [rclone coreutils];
    text = ''
      CONFIG="${cfg.configFile}"
      SRC="${cfg.source}"
      REMOTE="${cfg.remote}"
      BW="${cfg.bwLimit}"
      DRY=()
      usage(){ cat <<EOF
      Usage: vm-backup-push [-s SRC] [-r crypt-remote:] [-c rclone.conf] [-b bwlimit] [-n]
      Encrypts (rclone crypt) and copies export bundles to Cloudflare R2. Never deletes.
      EOF
      }
      while getopts "s:r:c:b:nh" o; do case "$o" in
        s) SRC="$OPTARG";; r) REMOTE="$OPTARG";; c) CONFIG="$OPTARG";;
        b) BW="$OPTARG";; n) DRY=(--dry-run);; h) usage; exit 0;;
        \?) echo "bad option; -h for help" >&2; exit 1;; esac; done
      shift $((OPTIND-1))
      if [ "$(id -u)" -ne 0 ]; then echo "run as root (reads root-owned exports/config): sudo vm-backup-push ..." >&2; exit 1; fi
      [ -f "$CONFIG" ] || { echo "rclone config not found: $CONFIG (make it with: rclone config)" >&2; exit 1; }
      [ -d "$SRC" ]   || { echo "source dir not found: $SRC" >&2; exit 1; }
      BWA=(); [ -n "$BW" ] && BWA=(--bwlimit "$BW")
      echo "Pushing $SRC -> $REMOTE (encrypted, copy-only)..."
      rclone copy "''${DRY[@]}" --config "$CONFIG" --transfers 4 --checkers 8 --fast-list --stats 30s "''${BWA[@]}" "$SRC" "$REMOTE"
      echo "Done."
    '';
  };
in {
  options.programs.vm-backup-push = {
    enable = mkEnableOption "Encrypted rclone push of VM export bundles to Cloudflare R2";
    source = mkOption {
      type = types.str;
      default = "/var/lib/libvirt/cold-export";
      description = "Directory of export bundles to push (match your exporter's outputDir).";
    };
    remote = mkOption {
      type = types.str;
      default = "r2crypt:";
      description = "rclone crypt remote (optionally with a subpath), e.g. r2crypt: or r2crypt:vms.";
    };
    configFile = mkOption {
      type = types.str;
      default = "/etc/rclone/r2.conf";
      description = "Path to the rclone config holding the R2 creds + crypt passwords. Keep it 0600, root-owned. NOT in the Nix store.";
    };
    bwLimit = mkOption {
      type = types.str;
      default = "";
      description = "Optional rclone --bwlimit (e.g. \"10M\"). Empty = unlimited.";
    };
    package = mkOption {
      type = types.package;
      readOnly = true;
      default = pushScript;
      description = "The push script package, for use by other modules.";
    };
  };
  config = mkIf cfg.enable {environment.systemPackages = [pushScript];};
}
