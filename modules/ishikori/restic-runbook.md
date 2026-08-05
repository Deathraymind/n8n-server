# VM Restic Backup Runbook

The restic version of the offsite backup. One command does it all: incremental
upload (only changed chunks), compression, encryption, and retention. It
replaces the old compress + rclone-push + prune chain.

Command: **`vm-restic-backup`** — run as root.

---

## What it does

For each VM **running on this node**, it:

1. freezes + ZFS-snapshots the disk,
2. flattens the chain into an uncompressed qcow2 in a scratch dir,
3. `restic backup`s that to R2 (dedups + compresses + encrypts on the way up),
4. `restic forget --prune`s to your keep-policy.

The uncompressed scratch is temporary and gets wiped after each run. What lands
in R2 is deduped + compressed, so it's much smaller than the scratch size.

---

## Multi-node rule (important)

Your VMs migrate between node1 and node2. The rule: **whichever node is running
the VM backs it up. The other node skips it.**

So to back up a VM from a specific machine, just make sure it's running there:

```
# on node2
sudo virsh start caddy         # or migrate it here
sudo vm-restic-backup caddy
```

Run it on the node where the VM _isn't_ running and it just skips that VM — no
error.

Both nodes push into the **same repo**, so caddy's history is one timeline no
matter which node made each backup, and restic dedups across both. For this to
work both nodes need:

- the same `repository` URL,
- the same `/etc/restic/vm-repo.pass`,
- the same `/etc/restic/r2.env`.

---

## Running it

```
sudo vm-restic-backup                 # all configured VMs running here
sudo vm-restic-backup caddy pelican   # just these
```

First run auto-creates ("inits") the repo.

---

## Where it's stored (the "bucket" part)

restic keeps everything in one **repository**, which lives inside your R2
bucket. The repo URL is set in the module:

```
repository = "s3:https://<accountid>.r2.cloudflarestorage.com/hypervisor-backups/restic";
```

Reading that: `hypervisor-backups` is the bucket (you already have it), and
`/restic` is a folder inside it holding the repo. You do **not** make a new
bucket per VM or per backup — it's all one repo. Everything is one bucket, one
folder, one encrypted repo.

If you'd rather keep restic separate from your old rclone bundles, make a fresh
bucket in the R2 dashboard (e.g. `vm-restic`) and point the URL at that instead:

```
repository = "s3:https://<accountid>.r2.cloudflarestorage.com/vm-restic/restic";
```

That's the only change — new bucket name in the URL. Same keys, same everything
else.

---

## Checking size

The big local scratch dir is NOT what's stored. Check the real footprint:

```
restic stats --mode raw-data   # actual bytes in the repo (after dedup + compression)
restic snapshots               # list of backups
```

(These need the env + password loaded, or just run them right after a backup on
the same box.)

Want more squeeze? Add `export RESTIC_COMPRESSION=max` — small gain, more CPU.

---

## Restoring

Different from the old bundle flow — you pull with restic, then hand off to
`qemu-live-import`.

```
restic snapshots                                   # pick which point in time
restic restore latest --target /tmp/restore --include caddy.qcow2
# that gives you /tmp/restore/.../caddy.qcow2 (+ caddy.xml)

sudo qemu-live-import -d /var/lib/libvirt/images/caddy -D /tmp/restore/...
sudo virsh start caddy
```

Use a snapshot ID instead of `latest` to restore an older version.

---

## Setup (one-time, per node)

Two secret files, kept out of the Nix store:

```
sudo mkdir -p /etc/restic
echo 'a-long-repo-password' | sudo tee /etc/restic/vm-repo.pass
sudo tee /etc/restic/r2.env <<'EOF'
AWS_ACCESS_KEY_ID=your_r2_access_key
AWS_SECRET_ACCESS_KEY=your_r2_secret_key
EOF
sudo chmod 600 /etc/restic/vm-repo.pass /etc/restic/r2.env
```

Enable in config:

```nix
programs.vm-restic-backup = {
  enable = true;
  vms = [ "caddy" "pelican" "vaultwarden" ];
  repository = "s3:https://<accountid>.r2.cloudflarestorage.com/hypervisor-backups/restic";
};
```

`nixos-rebuild switch`, done.

---

## ⚠️ Same warning as before

The **repo password** (`vm-repo.pass`) is the only thing that can decrypt these
backups. Lose it and the repo is unrecoverable — R2 can't help. Back it up
off-node (password manager). Same goes for keeping it identical on both nodes.

---

## Cheat sheet

```
sudo vm-restic-backup [vm ...]              # back up running VMs
restic snapshots                            # list backups
restic stats --mode raw-data                # real stored size
restic restore latest --target /tmp/r --include <vm>.qcow2
sudo qemu-live-import -d /var/lib/libvirt/images/<vm> -D /tmp/r/...
```
