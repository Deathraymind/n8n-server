terraform {
  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "~> 0.35.0"
    }
  }
}

provider "xenorchestra" {
  url      = "wss://192.168.1.140" # Change to wss:// if your XO uses SSL/HTTPS
  username = "admin@admin.net"
  password = "admin"
  insecure = true
}

# Look up your XCP-ng hardware pool and storage
data "xenorchestra_pool" "pool" {
  name_label = "xcp-ng-sdtwdpid"
}

data "xenorchestra_sr" "storage" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.pool.id
}

# Look up the NixOS VHD template you uploaded
data "xenorchestra_template" "nixos_base" {
  name_label = "caddy-base"
}

# Spin up the VM
resource "xenorchestra_vm" "caddy_server" {
  name_label       = "caddy-production"
  template         = data.xenorchestra_template.nixos_base.id
  
  cpus       = 2
  memory_max = 2147483648 # 2GB RAM

  disk {
    sr_id      = data.xenorchestra_sr.storage.id
    name_label = "Caddy OS Disk"
    size       = 21474836480 # 20GB
  }

  network {
    network_id = "0d23d95b-641d-a5a9-b08c-eb27b2da51df"
  }
}

# Output the IP address of the new VM so you know where it is
output "vm_ip" {
  value = xenorchestra_vm.caddy_server.ipv4_addresses[0]
}
