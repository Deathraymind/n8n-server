# Proxmox Cloud-Init Guide: Pelican Wings Token Provisioning

This streamlined guide covers how to securely inject Pelican Wings cluster
tokens into a guest VM using Proxmox Cloud-Init (`user-data`), avoiding
whitespace issues and permission race conditions.

---

## 1. Create the Snippet File (On Proxmox Host)

SSH into your **Proxmox VE host** and run the following command to create the
Cloud-Init configuration block.

_Note: Inline quotes `""` are used for the tokens to prevent trailing newlines
that cause 404 errors._

```bash
# Ensure the snippets directory exists
mkdir -p /var/lib/vz/snippets

# Create the user-data configuration file
cat << 'EOF' > /var/lib/vz/snippets/pelican-node1.yaml
#cloud-config
cloud_config_modules:
  - write_files

write_files:
  - path: /var/secrets/pelican/token_id
    permissions: '0644'
    owner: root:root
    content: "YOUR_PELICAN_NODE_TOKEN_ID"

  - path: /var/secrets/pelican/token
    permissions: '0644'
    owner: root:root
    content: "YOUR_PELICAN_NODE_TOKEN_SECRET"
EOF
```

> ⚠️ **Important:** Replace `YOUR_PELICAN_NODE_TOKEN_ID` and
> `YOUR_PELICAN_NODE_TOKEN_SECRET` with the actual keys from your Pelican Panel
> (**Admin Area** → **Nodes** → **Configuration**).

---

## 2. Link, Update, and Reboot (On Proxmox Host)

Run these commands on the Proxmox host to apply the configuration snippet to
your target VM.

_(Replace `<VM_ID>` with your actual Proxmox VM ID, e.g., `162`)_

```bash
# 1. Assign the snippet as custom user-data
qm set <VM_ID> --cicustom "user=local:snippets/pelican-node1.yaml"

# 2. Regenerate the Cloud-Init ISO
qm cloudinit update <VM_ID>

# 3. Reboot the VM to apply changes
qm reboot <VM_ID>
```

---

## 3. Post-Boot Verification (Inside the Guest VM)

Once the VM boots up, SSH into the **guest node** to verify that the tokens were
injected properly and securely:

```bash
# 1. Verify files exist with correct ownership
ls -la /var/secrets/pelican/

# 2. Confirm no hidden whitespaces or trailing newlines exist (should end directly with $)
cat -E /var/secrets/pelican/token_id

# 3. Check if the Pelican Wings service connected successfully
sudo systemctl status pelican-wings.service
```
