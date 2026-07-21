{
  pkgs,
  lib,
  config,
  ...
}: let
  influxUrl = "http://127.0.0.1:8086";
  influxOrg = "deathraymind";
  influxBucket = "snmp";

  # Starter dashboard, provisioned read-only into Grafana.
  dashboards = pkgs.writeTextDir "aruba-clients.json" (builtins.toJSON {
    title = "Aruba Instant — Wireless Clients";
    uid = "aruba-clients";
    schemaVersion = 39;
    version = 1;
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    panels = [
      {
        type = "stat";
        title = "Associated clients";
        id = 1;
        gridPos = {
          h = 5;
          w = 6;
          x = 0;
          y = 0;
        };
        datasource = {
          type = "influxdb";
          uid = "influxdb-snmp";
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: -10m)
                |> filter(fn: (r) => r._measurement == "aruba_instant_clients" and r._field == "client_ip")
                |> last()
                |> group()
                |> count(column: "_value")
            '';
          }
        ];
      }
      {
        type = "table";
        title = "Client table";
        id = 2;
        gridPos = {
          h = 14;
          w = 24;
          x = 0;
          y = 5;
        };
        datasource = {
          type = "influxdb";
          uid = "influxdb-snmp";
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: -10m)
                |> filter(fn: (r) => r._measurement == "aruba_instant_clients" and r._field == "client_ip")
                |> last()
                |> keep(columns: ["mac", "device_name", "connected_ap_ip", "_value"])
                |> rename(columns: {_value: "client_ip"})
                |> group()
            '';
          }
        ];
      }
    ];
  });
in {
  ############################################################
  # SECRETS (sops-nix)
  ############################################################
  sops.defaultSopsFile = ../../../secrets/monitoring.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # InfluxDB reads these as root during provisioning.
  sops.secrets."influxdb/adminPassword" = {};
  sops.secrets."influxdb/adminToken" = {};
  sops.secrets."influxdb/telegrafToken" = {};
  sops.secrets."influxdb/grafanaToken" = {};

  # Grafana reads these directly at runtime via $__file{}.
  sops.secrets."grafana/adminPassword" = {
    owner = "grafana";
    mode = "0400";
  };
  sops.secrets."grafana/influxToken" = {
    owner = "grafana";
    mode = "0400";
  };
  sops.secrets."grafana/secretKey" = {
    owner = "grafana";
    mode = "0400";
  };

  # Telegraf gets everything through one rendered env file.
  sops.secrets."snmp/authPassword" = {};
  sops.secrets."snmp/privPassword" = {};

  sops.templates."telegraf.env" = {
    owner = "telegraf";
    mode = "0400";
    content = ''
      INFLUX_TOKEN=${config.sops.placeholder."influxdb/telegrafToken"}
      SNMP_AUTH_PASSWORD=${config.sops.placeholder."snmp/authPassword"}
      SNMP_PRIV_PASSWORD=${config.sops.placeholder."snmp/privPassword"}
    '';
  };

  ############################################################
  # INFLUXDB 2 — declarative org, bucket, and tokens
  ############################################################
  services.influxdb2 = {
    enable = true;
    settings = {
      http-bind-address = "127.0.0.1:8086";
      reporting-disabled = true;
    };
    provision = {
      enable = true;
      initialSetup = {
        organization = influxOrg;
        bucket = influxBucket;
        username = "admin";
        passwordFile = config.sops.secrets."influxdb/adminPassword".path;
        tokenFile = config.sops.secrets."influxdb/adminToken".path;
        retention = 90 * 24 * 60 * 60; # 90d, 0 = infinite
      };
      organizations.${influxOrg}.auths = {
        telegraf = {
          description = "telegraf write access";
          writeBuckets = [influxBucket];
          tokenFile = config.sops.secrets."influxdb/telegrafToken".path;
        };
        grafana = {
          description = "grafana read access";
          readBuckets = [influxBucket];
          tokenFile = config.sops.secrets."influxdb/grafanaToken".path;
        };
      };
    };
  };

  ############################################################
  # TELEGRAF
  ############################################################
  services.telegraf = {
    enable = true;
    environmentFiles = [config.sops.templates."telegraf.env".path];
    extraConfig = {
      agent = {
        interval = "60s";
        flush_interval = "60s";
        round_interval = true;
        omit_hostname = false;
      };

      inputs.snmp = [
        {
          agents = ["udp://192.168.1.20:161"];
          timeout = "5s";
          retries = 2;
          version = 3;
          sec_name = "ArubaSNMP";
          sec_level = "authPriv";
          auth_protocol = "SHA";
          auth_password = "\${SNMP_AUTH_PASSWORD}";
          priv_protocol = "AES";
          priv_password = "\${SNMP_PRIV_PASSWORD}";
          table = [
            {
              name = "aruba_instant_clients";
              index_as_tag = true;
              field = [
                {
                  name = "client_ip";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.3";
                }
                {
                  name = "connected_ap_ip";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.4";
                }
                {
                  name = "device_name";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.5";
                }
              ];
            }
          ];
        }
      ];

      # 1. index (dotted decimal) -> mac tag
      processors.starlark = [
        {
          order = 1;
          namepass = ["aruba_instant_clients"];
          source = ''
            HEX = "0123456789abcdef"
            def apply(metric):
                idx = metric.tags.get("index")
                if idx == None:
                    return metric
                parts = idx.split(".")
                if len(parts) != 6:
                    return metric
                octets = []
                for p in parts:
                    n = int(p)
                    octets.append(HEX[n // 16] + HEX[n % 16])
                metric.tags["mac"] = ":".join(octets)
                metric.tags.pop("index")
                return metric
          '';
        }
      ];

      # 2. promote low-cardinality string fields to tags
      processors.converter = [
        {
          order = 2;
          namepass = ["aruba_instant_clients"];
          fields.tag = ["connected_ap_ip" "device_name"];
        }
      ];

      outputs.influxdb_v2 = [
        {
          urls = [influxUrl];
          token = "\${INFLUX_TOKEN}";
          organization = influxOrg;
          bucket = influxBucket;
        }
      ];
    };
  };

  systemd.services.telegraf = {
    after = ["influxdb2.service"];
    wants = ["influxdb2.service"];
    serviceConfig.Restart = lib.mkForce "always";
    serviceConfig.RestartSec = "10s";
  };

  ############################################################
  # GRAFANA — datasource + dashboards auto-provisioned
  ############################################################
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "grafana.deathraymind.net";
        root_url = "https://grafana.deathraymind.net/";
      };
      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.sops.secrets."grafana/adminPassword".path}}";
        secret_key = "$__file{${config.sops.secrets."grafana/secretKey".path}}";
        cookie_secure = true;
      };
      analytics.reporting_enabled = false;
      "auth.anonymous".enabled = false;
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        deleteDatasources = [
          {
            name = "InfluxDB";
            orgId = 1;
          }
        ];
        datasources = [
          {
            name = "InfluxDB";
            uid = "influxdb-snmp";
            type = "influxdb";
            access = "proxy";
            url = influxUrl;
            isDefault = true;
            jsonData = {
              version = "Flux";
              organization = influxOrg;
              defaultBucket = influxBucket;
              httpMode = "POST";
              timeInterval = "60s";
            };
            secureJsonData.token = "$__file{${config.sops.secrets."grafana/influxToken".path}}";
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "declarative";
            orgId = 1;
            type = "file";
            disableDeletion = true;
            allowUiUpdates = false;
            updateIntervalSeconds = 60;
            options.path = "${dashboards}";
          }
        ];
      };
    };
  };

  systemd.services.grafana = {
    after = ["influxdb2.service"];
    wants = ["influxdb2.service"];
  };

  networking.firewall.allowedTCPPorts = [3000];

  system.stateVersion = "25.05";
}
