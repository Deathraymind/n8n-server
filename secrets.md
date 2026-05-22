## 2. Create the Secret Snippet File

SSH into your primary **Proxmox node** and run the following block to create the
Cloud-Init configuration containing your Pelican Panel credentials.

```bash
# Ensure the snippets directory exists
mkdir -p /var/lib/vz/snippets

# Create the YAML configuration file
cat << 'EOF' > /var/lib/vz/snippets/pelican-secrets.yaml
#cloud-config
cloud_config_modules:
  - write_files
  - runcmd

write_files:
  - path: /var/secrets/cloudflare.env
    permissions: '0600'
    owner: root:root
    content: |
      CLOUDFLARE_DNS_API_TOKEN=randomtoken

  - path: /var/secrets/pelican/app.key
    permissions: '0640'
    owner: root:root
    content: |
      base64:3mY7bX9fS2kK4pQ5vWxN8zP1R4sT6uVwXyZ0A1B2C3D=

  - path: /var/secrets/pelican/dbpassword
    permissions: '0640'
    owner: root:root
    content: goon1234!!

  - path: /var/secrets/pelican/redispassword
    permissions: '0640'
    owner: root:root
    content: goon1234!!

  - path: /var/secrets/pelican/mailpassword
    permissions: '0640'
    owner: root:root
    content: good1234!!

# This executes at the very end of boot after NixOS creates the system groups
runcmd:
  - chown -R root:pelican-panel /var/secrets/pelican
  - chmod 750 /var/secrets/pelican
  - chmod 640 /var/secrets/pelican/*
EOF
```

> ⚠️ **Note:** Update the dummy values above with your actual production secrets
> before executing the script.

---

## 3. Link the Snippet to the VM

Attach your newly created vendor configuration to your specific target VM.

_(Replace `161` with your actual Proxmox VM ID if different)_

```bash
qm set 161 --cicustom "vendor=local:snippets/pelican-secrets.yaml"
```

---

## 4. Regenerate and Boot

Force Proxmox to rebuild the virtual Cloud-Init drive meta-structure and fire up
your VM:

```bash
qm cloudinit update 161
qm start 161
```

---

## 5. Verification Check (Inside the NixOS Guest)

Once your VM boots, SSH into your guest system (`ssh deathraymind@<vm-ip>`) and
confirm that the automated handoff executed correctly.

```bash
# Verify the secrets paths are populated and permissions are restricted
sudo ls -la /var/secrets/pelican/

# Verify the Pelican Panel service initialized correctly
sudo systemctl status pelican-panel.service
```
