{...}: {
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8081;
    openFirewall = true;
    allowedHosts = ["192.168.1.105:8081"];

    # Global Dashboard Settings
    settings = {
      title = "My Home Lab";
      theme = "dark";
      color = "slate";

      # Proxmox Providers passed inside global settings
      proxmox = {
        proxmox-node-1 = {
          url = "https://192.168.1.10:8006";
          username = "root@pam";
          password = "your-proxmox-password-1";
        };
        proxmox-node-2 = {
          url = "https://192.168.1.11:8006";
          username = "root@pam";
          password = "your-proxmox-password-2";
        };
      };

      # Grid Layout configuration
      layout = {
        "Cluster Management" = {
          style = "row";
          columns = 3;
        };
        "Self-Hosted Services" = {
          style = "row";
          columns = 3;
        };
      };
    };

    # Top-of-page Widgets
    widgets = [
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
    ];

    # Services Layout
    services = [
      {
        "Cluster Management" = [
          {
            "Proxmox VE 1" = {
              icon = "proxmox";
              href = "https://192.168.1.10:8006";
              description = "Primary Hypervisor";
              widget = {
                type = "proxmox";
                url = "https://192.168.1.10:8006";
                node = "pve1";
                username = "root@pam";
                password = "your-proxmox-password-1";
              };
            };
          }
          {
            "Proxmox VE 2" = {
              icon = "proxmox";
              href = "https://192.168.1.11:8006";
              description = "Secondary Hypervisor";
              widget = {
                type = "proxmox";
                url = "https://192.168.1.11:8006";
                node = "pve2";
                username = "root@pam";
                password = "your-proxmox-password-2";
              };
            };
          }
        ];
      }
      {
        "Self-Hosted Services" = [
          {
            "PufferPanel" = {
              icon = "pufferpanel";
              href = "https://panel.deathraymind.net";
              description = "Game Server Panel";
            };
          }
          {
            "Nextcloud" = {
              icon = "nextcloud";
              href = "https://nextcloud.deathraymind.net";
              description = "Cloud Storage";
            };
          }
          {
            "Syncthing" = {
              icon = "syncthing";
              href = "http://192.168.1.105:8384";
              description = "File Synchronization";
            };
          }
        ];
      }
    ];

    # Bookmarks Layout
    bookmarks = [
      {
        "Developer Tools" = [
          {
            GitHub = [
              {
                abbr = "GH";
                href = "https://github.com";
                icon = "github";
              }
            ];
          }
        ];
      }
    ];
  };
}
