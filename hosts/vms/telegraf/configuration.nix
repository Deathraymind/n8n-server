{
  pkgs,
  lib,
  config,
  ...
}: let
  influxUrl = "http://127.0.0.1:8086";
  influxOrg = "deathraymind";
  influxBucket = "snmp";

  # Single source of truth for the Grafana->Influx token.
  # influxdb2 owns it (the provision script reads it as that user),
  # grafana reads it via group. One file, so the two can never drift.
  grafanaTokenPath = config.sops.secrets."influxdb/grafanaToken".path;

  dsUid = "influxdb-snmp"; # datasource uid, referenced by every panel

  # Per-AP client table. One of these per AP, differing only by ip filter
  # and title. Joins current detail (last values) to current rate
  # (nonNegative derivative of the byte counters) on the client mac.
  # Uses join.left -> needs InfluxDB 2.7+ Flux (yours is fine).
  apClientTable = {
    id,
    x,
    title,
    apIp,
  }: {
    type = "table";
    inherit title id;
    gridPos = {
      h = 8;
      w = 8;
      inherit x;
      y = 18;
    };
    datasource = {
      type = "influxdb";
      uid = dsUid;
    };
    fieldConfig = {
      defaults = {};
      overrides = [
        {
          matcher = {
            id = "byName";
            options = "down_Bps";
          };
          properties = [
            {
              id = "unit";
              value = "Bps";
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "up_Bps";
          };
          properties = [
            {
              id = "unit";
              value = "Bps";
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "assoc_seconds";
          };
          properties = [
            {
              id = "unit";
              value = "s";
            }
          ];
        }
      ];
    };
    targets = [
      {
        refId = "A";
        query = ''
          import "join"

          detail = from(bucket: "${influxBucket}")
            |> range(start: -10m)
            |> filter(fn: (r) => r._measurement == "aruba_instant_clients" and (r._field == "client_ip" or r._field == "snr" or r._field == "channel" or r._field == "assoc_seconds"))
            |> filter(fn: (r) => r.connected_ap_ip == "${apIp}")
            |> last()
            |> pivot(rowKey: ["mac", "device_name", "os"], columnKey: ["_field"], valueColumn: "_value")

          rates = from(bucket: "${influxBucket}")
            |> range(start: -10m)
            |> filter(fn: (r) => r._measurement == "aruba_instant_clients" and (r._field == "rx_bytes" or r._field == "tx_bytes"))
            |> filter(fn: (r) => r.connected_ap_ip == "${apIp}")
            |> derivative(unit: 1s, nonNegative: true)
            |> last()
            |> pivot(rowKey: ["mac"], columnKey: ["_field"], valueColumn: "_value")
            |> rename(columns: {rx_bytes: "down_Bps", tx_bytes: "up_Bps"})

          join.left(
            left: detail,
            right: rates,
            on: (l, r) => l.mac == r.mac,
            as: (l, r) => ({l with down_Bps: r.down_Bps, up_Bps: r.up_Bps}),
          )
            |> rename(columns: {device_name: "hostname", client_ip: "ip"})
            |> keep(columns: ["hostname", "ip", "mac", "os", "snr", "channel", "assoc_seconds", "down_Bps", "up_Bps"])
            |> group()
            |> sort(columns: ["down_Bps"], desc: true)
        '';
      }
    ];
  };

  # Provisioned read-only into Grafana. Same uid, bumped version so
  # Grafana accepts the overwrite on redeploy.
  dashboards = pkgs.writeTextDir "aruba-clients.json" (builtins.toJSON {
    title = "Aruba Instant — Wireless";
    uid = "aruba-clients";
    schemaVersion = 39;
    version = 4;
    refresh = "30s";
    time = {
      from = "now-1h";
      to = "now";
    };
    panels = [
      ##########################################################
      # ROW 1 — headline + per-AP overview
      ##########################################################
      {
        type = "stat";
        title = "Total wireless clients";
        id = 1;
        gridPos = {
          h = 5;
          w = 4;
          x = 0;
          y = 0;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
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
        title = "Clients per AP";
        id = 2;
        gridPos = {
          h = 5;
          w = 6;
          x = 4;
          y = 0;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: -10m)
                |> filter(fn: (r) => r._measurement == "aruba_instant_clients" and r._field == "client_ip")
                |> last()
                |> group(columns: ["connected_ap_ip"])
                |> count(column: "_value")
                |> group()
                |> rename(columns: {_value: "clients", connected_ap_ip: "ap_ip"})
                |> keep(columns: ["ap_ip", "clients"])
            '';
          }
        ];
      }

      {
        type = "table";
        title = "AP overview";
        id = 3;
        gridPos = {
          h = 5;
          w = 14;
          x = 10;
          y = 0;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        fieldConfig = {
          defaults = {};
          overrides = [
            {
              matcher = {
                id = "byName";
                options = "cpu";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "mem_used_pct";
              };
              properties = [
                {
                  id = "unit";
                  value = "percent";
                }
              ];
            }
          ];
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: -10m)
                |> filter(fn: (r) => r._measurement == "aruba_instant_aps" and (r._field == "cpu" or r._field == "mem_used_pct" or r._field == "status"))
                |> last()
                |> pivot(rowKey: ["mac", "name", "ip"], columnKey: ["_field"], valueColumn: "_value")
                |> keep(columns: ["name", "ip", "mac", "cpu", "mem_used_pct", "status"])
                |> group()
            '';
          }
        ];
      }

      ##########################################################
      # ROW 2 — AP time series (cpu / mem / throughput)
      ##########################################################
      {
        type = "timeseries";
        title = "AP CPU %";
        id = 4;
        gridPos = {
          h = 7;
          w = 8;
          x = 0;
          y = 5;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
            min = 0;
          };
          overrides = [];
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
                |> filter(fn: (r) => r._measurement == "aruba_instant_aps" and r._field == "cpu")
                |> group(columns: ["name"])
                |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
            '';
          }
        ];
      }

      {
        type = "timeseries";
        title = "AP memory usage %";
        id = 5;
        gridPos = {
          h = 7;
          w = 8;
          x = 8;
          y = 5;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        fieldConfig = {
          defaults = {
            unit = "percent";
            min = 0;
            max = 100;
          };
          overrides = [];
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
                |> filter(fn: (r) => r._measurement == "aruba_instant_aps" and r._field == "mem_used_pct")
                |> group(columns: ["name"])
                |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
            '';
          }
        ];
      }

      # Per-AP throughput: derivative per radio, then sum radios per AP.
      {
        type = "timeseries";
        title = "AP throughput (tx/rx)";
        id = 6;
        gridPos = {
          h = 7;
          w = 8;
          x = 16;
          y = 5;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        fieldConfig = {
          defaults = {
            unit = "Bps";
            min = 0;
          };
          overrides = [];
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
                |> filter(fn: (r) => r._measurement == "aruba_instant_radios" and (r._field == "tx_bytes" or r._field == "rx_bytes"))
                |> group(columns: ["mac", "_field", "radio_no"])
                |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
                |> derivative(unit: 1s, nonNegative: true)
                |> group(columns: ["mac", "_field"])
                |> aggregateWindow(every: v.windowPeriod, fn: sum, createEmpty: false)
            '';
          }
        ];
      }

      ##########################################################
      # ROW 3 — cumulative AP totals + top talkers
      ##########################################################
      {
        type = "table";
        title = "AP data totals (since boot)";
        id = 7;
        gridPos = {
          h = 6;
          w = 10;
          x = 0;
          y = 12;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        fieldConfig = {
          defaults = {};
          overrides = [
            {
              matcher = {
                id = "byName";
                options = "tx_bytes";
              };
              properties = [
                {
                  id = "unit";
                  value = "bytes";
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "rx_bytes";
              };
              properties = [
                {
                  id = "unit";
                  value = "bytes";
                }
              ];
            }
          ];
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: -10m)
                |> filter(fn: (r) => r._measurement == "aruba_instant_radios" and (r._field == "tx_bytes" or r._field == "rx_bytes"))
                |> last()
                |> group(columns: ["mac", "_field"])
                |> sum()
                |> pivot(rowKey: ["mac"], columnKey: ["_field"], valueColumn: "_value")
                |> group()
                |> keep(columns: ["mac", "tx_bytes", "rx_bytes"])
            '';
          }
        ];
      }

      # Top talkers: every client, current down/up rate, sorted by download.
      {
        type = "table";
        title = "Top talkers (live rate)";
        id = 8;
        gridPos = {
          h = 6;
          w = 14;
          x = 10;
          y = 12;
        };
        datasource = {
          type = "influxdb";
          uid = dsUid;
        };
        fieldConfig = {
          defaults = {};
          overrides = [
            {
              matcher = {
                id = "byName";
                options = "down_Bps";
              };
              properties = [
                {
                  id = "unit";
                  value = "Bps";
                }
              ];
            }
            {
              matcher = {
                id = "byName";
                options = "up_Bps";
              };
              properties = [
                {
                  id = "unit";
                  value = "Bps";
                }
              ];
            }
          ];
        };
        targets = [
          {
            refId = "A";
            query = ''
              from(bucket: "${influxBucket}")
                |> range(start: -10m)
                |> filter(fn: (r) => r._measurement == "aruba_instant_clients" and (r._field == "rx_bytes" or r._field == "tx_bytes"))
                |> derivative(unit: 1s, nonNegative: true)
                |> last()
                |> pivot(rowKey: ["mac", "connected_ap_ip", "device_name"], columnKey: ["_field"], valueColumn: "_value")
                |> rename(columns: {rx_bytes: "down_Bps", tx_bytes: "up_Bps", device_name: "hostname", connected_ap_ip: "ap"})
                |> keep(columns: ["hostname", "mac", "ap", "down_Bps", "up_Bps"])
                |> group()
                |> sort(columns: ["down_Bps"], desc: true)
            '';
          }
        ];
      }

      ##########################################################
      # ROW 4 — one detail table per AP
      ##########################################################
      (apClientTable {
        id = 9;
        x = 0;
        title = "aruba-01 (.20) clients";
        apIp = "192.168.1.20";
      })
      (apClientTable {
        id = 10;
        x = 8;
        title = "aruba-02 (.21) clients";
        apIp = "192.168.1.21";
      })
      (apClientTable {
        id = 11;
        x = 16;
        title = "aruba-03 (.22) clients";
        apIp = "192.168.1.22";
      })
    ];
  });
in {
  ############################################################
  # SECRETS (sops-nix)
  ############################################################
  sops.defaultSopsFile = ../../../secrets/monitoring.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # influxdb2's provision script runs INSIDE the unit as the influxdb2
  # user and open()s these paths directly -- hence owner, not root.
  sops.secrets."influxdb/adminPassword" = {
    owner = "influxdb2";
    mode = "0400";
  };
  sops.secrets."influxdb/adminToken" = {
    owner = "influxdb2";
    mode = "0400";
  };
  sops.secrets."influxdb/telegrafToken" = {
    owner = "influxdb2";
    mode = "0400";
  };
  # Read by influxdb2 (creates the auth) AND grafana (uses it) -> group.
  sops.secrets."influxdb/grafanaToken" = {
    owner = "influxdb2";
    group = "grafana";
    mode = "0440";
  };

  # Grafana reads these at runtime via its $__file{} provider.
  sops.secrets."grafana/adminPassword" = {
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
          tokenFile = grafanaTokenPath;
        };
      };
    };
  };

  # Don't let a slow dependency latch the unit into start-limit-hit.
  systemd.services.influxdb2 = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = "5s";
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
            ####################################################
            # CLIENTS — identity + signal + per-client counters
            # rx_bytes = download to client, tx_bytes = upload from
            # client (INFERRED from magnitudes; verify with a big
            # download and swap .9/.13 if backwards).
            ####################################################
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
                {
                  name = "os";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.6";
                }
                {
                  name = "snr";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.7";
                }
                {
                  name = "rx_bytes";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.9";
                }
                {
                  name = "tx_bytes";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.13";
                }
                {
                  name = "channel";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.15";
                }
                {
                  name = "assoc_uptime";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.4.1.16";
                }
              ];
            }

            ####################################################
            # AP TABLE — per-AP cpu + memory
            ####################################################
            {
              name = "aruba_instant_aps";
              index_as_tag = true;
              field = [
                {
                  name = "name";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.2";
                  is_tag = true;
                }
                {
                  name = "ip";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.3";
                  is_tag = true;
                }
                {
                  name = "serial";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.4";
                  is_tag = true;
                }
                {
                  name = "model";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.6";
                  is_tag = true;
                }
                {
                  name = "cpu";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.7";
                }
                {
                  name = "mem_free";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.8";
                }
                {
                  name = "uptime";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.9";
                }
                {
                  name = "mem_total";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.10";
                }
                {
                  name = "status";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.1.1.11";
                }
              ];
            }

            ####################################################
            # RADIO TABLE — per-radio tx/rx bytes (summed per AP)
            ####################################################
            {
              name = "aruba_instant_radios";
              index_as_tag = true;
              field = [
                {
                  name = "tx_bytes";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.2.1.12";
                }
                {
                  name = "rx_bytes";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.2.1.16";
                }
                {
                  name = "status";
                  oid = ".1.3.6.1.4.1.14823.2.3.3.1.2.2.1.20";
                }
              ];
            }
          ];
        }
      ];

      # order 1: index -> mac. 6-octet (client/AP) or 7-octet (radio,
      # 7th octet -> radio_no).
      processors.starlark = [
        {
          order = 1;
          namepass = [
            "aruba_instant_clients"
            "aruba_instant_aps"
            "aruba_instant_radios"
          ];
          source = ''
            HEX = "0123456789abcdef"
            def apply(metric):
                idx = metric.tags.get("index")
                if idx == None:
                    return metric
                parts = idx.split(".")
                if len(parts) < 6:
                    return metric
                octets = []
                for p in parts[:6]:
                    n = int(p)
                    octets.append(HEX[n // 16] + HEX[n % 16])
                metric.tags["mac"] = ":".join(octets)
                if len(parts) == 7:
                    metric.tags["radio_no"] = parts[6]
                metric.tags.pop("index")
                return metric
          '';
        }

        # order 3: derive AP memory usage (used = total - free)
        {
          order = 3;
          namepass = ["aruba_instant_aps"];
          source = ''
            def apply(metric):
                free = metric.fields.get("mem_free")
                total = metric.fields.get("mem_total")
                if free != None and total != None and total > 0:
                    used = total - free
                    metric.fields["mem_used"] = used
                    metric.fields["mem_used_pct"] = (used * 100.0) / total
                return metric
          '';
        }

        # order 4 (clients, after the converter promotes tags): backfill
        # empty identity tags so table columns always exist, and turn
        # assoc_uptime (1/100 s ticks) into whole seconds.
        {
          order = 4;
          namepass = ["aruba_instant_clients"];
          source = ''
            def apply(metric):
                for t in ["connected_ap_ip", "device_name", "os"]:
                    v = metric.tags.get(t)
                    if v == None or v == "":
                        metric.tags[t] = "-"
                au = metric.fields.get("assoc_uptime")
                if au != None:
                    metric.fields["assoc_seconds"] = int(au) // 100
                return metric
          '';
        }
      ];

      # order 2: promote low-cardinality client string fields to tags
      processors.converter = [
        {
          order = 2;
          namepass = ["aruba_instant_clients"];
          fields.tag = ["connected_ap_ip" "device_name" "os"];
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
    unitConfig.StartLimitIntervalSec = 0;
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
        # If you hit this over plain http://IP:3000 instead of via TLS,
        # set this false and point root_url at http://IP:3000/ or login
        # will silently bounce you back to the login page.
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
            secureJsonData.token = "$__file{${grafanaTokenPath}}";
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
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = "5s";
  };

  environment.systemPackages = with pkgs; [
    influxdb2-cli
    net-snmp
  ];

  networking.firewall.allowedTCPPorts = [3000 8086];

  system.stateVersion = "25.05";
}
