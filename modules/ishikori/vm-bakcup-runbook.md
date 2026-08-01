# VM Backup Runbook

How the offsite VM backup setup works, and the commands to run. Three tools, all
run as root, all standalone NixOS modules.

- **`qemu-live-export`** — snapshots a VM, flattens the disk chain into one
  compressed file, drops a restore bundle.
- **`qemu-live-import`** — takes a bundle, decrypts/inflates it, and rebuilds
  the disk (optionally re-defines the VM).
- **`vm-backup-push`** — encrypts the bundles and copies them to Cloudflare R2.

The chain is: **export → push → (disaster) → pull → import.**

---

## The pieces

- Backups land locally in `/srv/share/cold-export/` as one folder per VM per
  run: the compressed disk, the domain XML, and a `SHA256SUMS`.
- Offsite copy lives in the Cloudflare R2 bucket `hypervisor-backups`, under
  `vms/`, **encrypted** (scrambled names + contents).
- rclone config with the R2 keys + encryption password lives at
  `/etc/rclone/r2.conf` on node2. This file is critical — more on that below.

---

## Making backups

Export one or more VMs (or all configured ones if you pass no names):

```
sudo qemu-live-export caddy pelican
sudo qemu-live-export            # all configured VMs
```

That writes bundles into `/srv/share/cold-export/`. It's safe on running VMs —
it freezes a snapshot, flattens from that, and leaves the VM alone.

Push them offsite (encrypted):

```
sudo vm-backup-push -s /srv/share/cold-export        # uses the r2crypt: default
sudo vm-backup-push -s /srv/share/cold-export -n     # dry run, shows what'd upload
sudo vm-backup-push -s /srv/share/cold-export -b 10M # cap bandwidth
```

It's copy-only — never deletes anything on R2, and skips files already uploaded.
Do this at least weekly.

**Sanity check:** in the R2 dashboard you should see a `vms/` folder full of
gibberish filenames. If you can read `caddy.qcow2.zst` in plain text, it went up
unencrypted — you pushed to the wrong remote.

---

## Restoring (same machine)

Pull a bundle back and import it:

```
rclone copy r2crypt:caddy-2026-08-01_04h50m03s ./caddy-restore --config /etc/rclone/r2.conf -P
sudo qemu-live-import -d /var/lib/libvirt/images/caddy -D ./caddy-restore
```

`qemu-live-import` verifies the checksums, inflates the disk, rewrites the XML's
disk path, and defines the VM. Then `sudo virsh start caddy`.

Flags (they go **before** the bundle path):

- `-d DIR` — where to put the disk
- `-D` — also define the VM from the bundle XML
- `-f` — overwrite an existing disk
- `-n NAME` — override the VM name

Tip: for a VM you want the nightly job to protect again, restore into a ZFS
dataset first: `sudo zfs create vmpool/images/caddy`, then
`-d /var/lib/libvirt/images/caddy`.

---

## Restoring on a NEW machine

You need two things: **rclone**, and the **rclone config** (or the crypt
password + salt). Without the crypt password the download is undecryptable
noise.

```
mkdir -p /etc/rclone
scp deathraymind@node2:/etc/rclone/r2.conf /etc/rclone/   # or restore from your password manager

rclone lsd r2crypt: --config /etc/rclone/r2.conf          # lists bundles (names decrypt on the fly)
rclone copy r2crypt:caddy-2026-08-01_04h50m03s ./caddy-restore --config /etc/rclone/r2.conf -P

sudo qemu-live-import -d /var/lib/libvirt/images/caddy -D ./caddy-restore
```

No `r2.conf`? Rebuild the two remotes by hand with `rclone config` using the
**exact same** crypt password + salt (see below). Same inputs = same decryption.

---

## The R2 / rclone setup (one-time)

Two remotes in `/etc/rclone/r2.conf`:

1. **`hypervisor-backups`** — type `s3`, provider `Cloudflare`, your R2 access
   key + secret, endpoint `https://<accountid>.r2.cloudflarestorage.com`, region
   `auto`.
2. **`r2crypt`** — type `crypt`,
   `remote = hypervisor-backups:hypervisor-backups/vms`, filename encryption
   `standard`, dir name encryption `yes`, plus a password + salt.

The mental model:

- `hypervisor-backups:` = the remote (how rclone reaches R2)
- `hypervisor-backups` after the colon = the bucket
- `/vms` = folder in the bucket
- `r2crypt:` = all of the above **plus encryption**

So once `r2crypt` exists, you only ever type `r2crypt:` — no bucket name needed,
it's baked in. All the encryption happens locally on node2; Cloudflare only ever
sees encrypted blobs.

Lock the file down: `sudo chmod 600 /etc/rclone/r2.conf`.

---

## ⚠️ The one thing that can kill you

The crypt **password + salt** in `r2.conf` is the _only_ thing that can decrypt
your backups. Cloudflare doesn't have it and can't recover it. Lose it and every
offsite backup is permanently unreadable.

**Back up the crypt password + salt somewhere off node2** — a password manager
is perfect.

---

## Also: actually test it

A restore path you've never run is the thing that fails on the day you need it.
Once, on a spare machine: pull one bundle, run it through `qemu-live-import`,
boot it. Then you know it works.

---

## Cheat sheet

```
# make + push backups
sudo qemu-live-export caddy pelican
sudo vm-backup-push -s /srv/share/cold-export

# list what's offsite
rclone lsd r2crypt: --config /etc/rclone/r2.conf

# restore
rclone copy r2crypt:<bundle-folder> ./restore --config /etc/rclone/r2.conf -P
sudo qemu-live-import -d /var/lib/libvirt/images/<vm> -D ./restore
sudo virsh start <vm>
```
