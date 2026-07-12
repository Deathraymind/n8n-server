{pkgs, ...}: let
  background = ./background.jpg; # relative to this nix file

  homepageWithBg = pkgs.homepage-dashboard.overrideAttrs (oldAttrs: {
    postInstall = ''
      mkdir -p $out/share/homepage/public/images
      ln -s ${background} $out/share/homepage/public/images/background.jpg
    '';
  });
in {
  services.homepage-dashboard = {
    enable = true;
    package = homepageWithBg;
    listenPort = 8081;
    openFirewall = true;
    allowedHosts = "192.168.1.105:8081";

    settings = {
      title = "My Home Lab";
      theme = "stone";
      color = "slate";
      cardBlur = "sm";
      background = {
        image = "/images/background.jpg";
        opacity = 40;
        blur = "sm";
        saturate = 80;
        brightness = 60;
      };
      # ... rest of your settings
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

    customCSS = ''
                       /* ── Oxocarbon surface variables ── */
      :root {
        --background:       #161616;
        --surfacePrimary:   #161616;
        --surfaceSecondary: #262626;
        --surfaceHover:     #353535;
        --surfaceSelect:    #474747;
        --surfaceElevated:  #2c2c2c;
        --surfaceOverlay:   #1f1f1f;
        --surfaceAccent:    #393939;
        --divider:          #161616;
        --icon:             #78a9ff;
        --textPrimary:      #dde1e6;
        --textSecondary:    #878d96;
        --blue:             #78a9ff;
        --dark-blue:        rgba(120, 169, 255, 0.15);
        --red:              #ff7eb6;
        --dark-red:         rgba(255, 126, 182, 0.15);
        --grey:             #525252;
        --moon-grey:        #f2f4f8;
        --green:            #42be65;
        --green-light:      #6fdc8c;
        --hover-blue:       rgba(120, 169, 255, 0.12);
        --selection-bg:     #393939;
        --shell-bg:         #2c2c2c;
        --radius:           0.7rem;
        
        /* ── Glass effect controls ── */
        --card-opacity:     0.85;
        --card-blur:        10px;
        --widget-opacity:   0.9;
        --widget-blur:      8px;
        --group-opacity:    0.8;
        --group-blur:       12px;
      }

      /* ── Page background: deepest layer ── */
      body,
      #page_container,
      main {
        background-color: var(--background) !important;
        background-image: url('https://raw.githubusercontent.com/Deathraymind/n8n-server/main/hosts/nas/background.jpg') !important;
        background-size: cover !important;
        background-position: center !important;
        background-attachment: fixed !important;
      }

      /* ── Top-level widget bar: one step up ── */
      #information-widgets,
      .information-widget-base {
        background-color: var(--surfaceOverlay) !important;
        border: 1px solid var(--surfaceAccent) !important;
        padding: 0.75rem 1rem !important;
        border-radius: calc(var(--radius) * 1.5) !important;
        backdrop-filter: blur(var(--widget-blur)) !important;
        opacity: var(--widget-opacity) !important;
      }

      /* ── Group/category headers ── */
      services > div > div:first-child,
      .services-group-header,
      [class*="service-group"] > :first-child {
        color: var(--blue) !important;
        font-size: 0.7rem !important;
        letter-spacing: 0.12em !important;
        text-transform: uppercase !important;
        opacity: 0.85;
      }

      /* ── Service group containers: mid layer ── */
      .services-group,
      [class*="service-group"],
      #services > div {
        background-color: var(--surfaceSecondary) !important;
        border: 1px solid var(--surfaceAccent) !important;
        margin-bottom: 1rem !important;
        border-radius: calc(var(--radius) * 2) !important;
        padding: 1rem !important;
        backdrop-filter: blur(var(--group-blur)) !important;
        opacity: var(--group-opacity) !important;
      }

      /* ── Individual service cards: elevated above group ── */
      .service-card,
      [class*="service-card"],
      #services li {
        background-color: var(--surfaceElevated) !important;
        border: 1px solid var(--surfaceSelect) !important;
        border-radius: var(--radius) !important;
        transition: background-color 0.15s ease, border-color 0.15s ease, opacity 0.15s ease !important;
        backdrop-filter: blur(var(--card-blur)) !important;
        opacity: var(--card-opacity) !important;
      }

      /* ── Card hover: top surface ── */
      .service-card:hover,
      [class*="service-card"]:hover,
      #services li:hover {
        background-color: var(--surfaceHover) !important;
        border-color: var(--blue) !important;
        opacity: 1 !important;
      }

      /* ── Service icon wrapper ── */
      .service-icon,
      [class*="service-icon"] {
        background-color: var(--dark-blue) !important;
        border-radius: calc(var(--radius) * 0.85) !important;
        padding: 0.35rem !important;
      }

      /* ── Text ── */
      .service-name,
      [class*="service-title"],
      .text-theme-800 {
        color: var(--textPrimary) !important;
      }

      .service-description,
      [class*="text-theme-500"],
      .text-theme-500 {
        color: var(--textSecondary) !important;
      }

      /* ── Links ── */
      a {
        color: var(--textPrimary) !important;
        text-decoration: none !important;
      }
      a:hover {
        color: var(--blue) !important;
      }

      /* ── Search bar ── */
      input[type="text"],
      [class*="search"] input,
      .search-input {
        background-color: var(--surfaceSecondary) !important;
        border: 1px solid var(--surfaceAccent) !important;
        border-radius: 9999px !important;
        color: var(--textPrimary) !important;
        padding: 0.5rem 1rem !important;
        backdrop-filter: blur(var(--card-blur)) !important;
      }
      input[type="text"]:focus,
      .search-input:focus {
        border-color: var(--blue) !important;
        background-color: var(--surfaceElevated) !important;
        outline: none !important;
        box-shadow: 0 0 0 2px var(--dark-blue) !important;
      }

      /* ── Resource / stat widgets ── */
      .resource-value,
      [class*="resource"] span {
        color: var(--blue) !important;
      }

      /* ── Dividers ── */
      hr, [class*="divider"] {
        border-color: var(--surfaceAccent) !important;
        opacity: 0.5;
      }

      /* ── Scrollbar ── */
      ::-webkit-scrollbar       { width: 5px; }
      ::-webkit-scrollbar-track { background: var(--background); }
      ::-webkit-scrollbar-thumb {
        background: var(--surfaceAccent);
        border-radius: 9999px;
      }

      /* ── Developer Tools Theme ── */
      /* DevTools background */
      .sources .navigator,
      .styles-section,
      .elements-disclosure,
      .console-view {
        background-color: var(--surfacePrimary) !important;
      }

      /* DevTools panels */
      .panel,
      .tabbed-pane,
      .vbox,
      .split-widget {
        background-color: var(--background) !important;
      }

      /* DevTools sidebar */
      .navigator-tabbed-pane,
      .sidebar-pane {
        background-color: var(--surfaceSecondary) !important;
      }

      /* DevTools text */
      .devtools-link,
      .source-code,
      .webkit-html-tag,
      .webkit-css-property {
        color: var(--textPrimary) !important;
      }

      /* DevTools selection */
      ::selection {
        background-color: var(--selection-bg) !important;
        color: var(--textPrimary) !important;
      }

      /* Console messages */
      .console-message-text {
        color: var(--textPrimary) !important;
      }

      .console-error-level {
        color: var(--red) !important;
      }

      .console-warning-level {
        color: var(--green-light) !important;
      }

      /* Syntax highlighting in DevTools */
      .cm-keyword { color: var(--red) !important; }
      .cm-atom { color: var(--blue) !important; }
      .cm-number { color: var(--green) !important; }
      .cm-def { color: var(--textPrimary) !important; }
      .cm-variable { color: var(--blue) !important; }
      .cm-variable-2 { color: var(--green-light) !important; }
      .cm-string { color: var(--green) !important; }
      .cm-comment { color: var(--textSecondary) !important; }
      .cm-tag { color: var(--red) !important; }
      .cm-attribute { color: var(--blue) !important; }    '';

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

    services = [
      {
        "Cluster Management" = [
          {
            "Proxmox VE 1" = {
              icon = "proxmox";
              href = "https://192.168.1.144:8006";
              description = "Primary Hypervisor";
              widget = {
                type = "proxmox";
                url = "https://192.168.1.144:8006";
                node = "pve1";
                username = "root@pam";
                password = "your-proxmox-password-1";
              };
            };
          }
          {
            "Proxmox VE 2" = {
              icon = "proxmox";
              href = "https://192.168.1.201:8006";
              description = "Secondary Hypervisor";
              widget = {
                type = "proxmox";
                url = "https://192.168.1.201:8006";
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
              icon = "pelicanpanel";
              href = "https://panel.deathraymind.net";
              description = "Game Server Panel";
            };
          }
          {
            "Peerdrop" = {
              icon = "peerdrop";
              href = "http://192.168.1.105:3000";
              description = "Local File Sharing";
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
