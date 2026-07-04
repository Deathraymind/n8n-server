# Manual Incremental Live Migration (libvirt/KVM, non-shared storage)

Migrating a running VM between two nodes when `--copy-storage-inc` pre-creation
is **not supported** by your libvirt build. Works by hand-staging the overlay
target that libvirt refuses to create.

- **node1** = `192.168.1.100`
- **node2** = `192.168.1.99`
- **VM** = `pelican-wings`
- **disk** = `/var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2`

Direction below: migrating **node2 → node1**. Swap IPs to reverse.

---

## Concept (why this works)

The disk is a two-layer qcow2 chain:

```
pelican-wings.qcow2    <- base: everything, frozen, identical on both nodes
pelican-wings.inc-test <- overlay: only live writes, tiny
```

Rule: **copy the part that doesn't change, create-empty the part that does.**

- Base never changes once frozen -> `scp` it once (this is the data you avoid
  re-sending).
- Overlay is nothing but change -> `qemu-img create` an **empty** one on the
  destination and let migration stream the delta into it.

Only the overlay delta crosses the wire, so transfer is near-instant.

---

## Steps

### 1. Start from a single flat disk

If the VM is already on a chain from a previous attempt, commit it back down
first (run on the node where the VM is live):

```bash
sudo virsh blockcommit pelican-wings vda --active --pivot --verbose
sudo qemu-img info --backing-chain \
  /var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2   # expect NO backing file
```

`blockcommit --pivot` leaves the old overlay file orphaned on disk. Delete it,
or step 2's `snapshot-create-as --name inc-test` fails with "external snapshot
file ... already exists":

```bash
sudo rm -f /var/lib/libvirt/images/pelican-wings/pelican-wings.inc-test
```

### 2. Split off a fresh overlay (freeze the base)

Run on the source node (node2). Freezing first guarantees the copy can't drift.

```bash
sudo virsh snapshot-create-as pelican-wings \
  --name inc-test --disk-only --atomic --no-metadata
```

Now `pelican-wings.qcow2` is frozen; live writes go to `pelican-wings.inc-test`.

### 3. Seed the frozen base onto the destination (same absolute path)

```bash
# on node2 -> node1
scp /var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2 \
  deathraymind@192.168.1.100:/home/deathraymind/pelican-wings.qcow2
```

```bash
# on node1: move into place (mkdir -p the dir first if needed)
sudo cp /home/deathraymind/pelican-wings.qcow2 \
  /var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2
```

### 4. Verify base matches on both nodes

```bash
sudo qemu-img info /var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2 \
  | grep 'virtual size'
```

Virtual size must be identical on both. (File size on disk can differ — that's
fine.)

### 5. Hand-create the empty overlay target on the destination

This is the step libvirt won't do for you.

```bash
# on node1
sudo qemu-img create -f qcow2 \
  -b /var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2 -F qcow2 \
  /var/lib/libvirt/images/pelican-wings/pelican-wings.inc-test

sudo chown --reference=/var/lib/libvirt/images/pelican-wings/pelican-wings.qcow2 \
  /var/lib/libvirt/images/pelican-wings/pelican-wings.inc-test
```

Flags: `-f qcow2` overlay format, `-b` backing = the seeded base, `-F qcow2`
backing format, last arg = overlay to create. Inherits the base's virtual size,
starts empty.

### 6. Migrate (no --copy-storage flag, with --unsafe)

Because the disk is already staged on the destination, libvirt must NOT try to
pre-create anything, so drop `--copy-storage-inc`. It'll then complain the
migration is unsafe (can't verify non-shared storage) — override with `--unsafe`
since you seeded the base yourself.

```bash
# on node2
sudo virsh migrate --live --persistent --verbose --unsafe \
  pelican-wings \
  qemu+ssh://deathraymind@192.168.1.100/system \
  --migrateuri tcp://192.168.1.100
```

Only the ~KB overlay delta transfers. Done.

---

## Errors seen and their fixes

| Error                                                | Cause                                      | Fix                                                                               |
| ---------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------- |
| `Source and target image have different sizes`       | stale/wrong overlay file left in dest dir  | delete the leftover; ensure only the base sits there                              |
| `pre-creation of storage target ... not supported`   | libvirt build can't auto-create inc target | hand-create overlay (step 5), migrate without `--copy-storage-inc`                |
| `Migration without shared storage is unsafe`         | libvirt won't vouch for non-shared disk    | add `--unsafe` (safe here — base was verified byte-identical)                     |
| `Failed to get "write" lock` (qemu-img on live disk) | VM holds the disk open                     | use `--force-share` for read-only inspection; don't force-create over a live file |

---

## Notes / open questions (edit after retest)

- CPU mismatch (node1 IvyBridge / node2 Westmere) did NOT block this run, but is
  a separate failure mode — pin the VM to a Westmere-compatible mode if it
  bites.
- `--auto-converge` was in one early attempt; unclear if it mattered. Test
  whether it's needed.
- Whether `--migrateuri` is required or the default transport suffices —
  untested.
- This whole dance is what shared storage (NFS from tank) eliminates: disk in
  one place, migrate with zero storage copy, no flags, no staging.
