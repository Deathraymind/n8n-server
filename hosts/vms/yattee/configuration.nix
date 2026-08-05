{
  pkgs,
  lib,
  ...
}: {
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # No published image exists, so clone + build it locally first.
  systemd.services.yattee-server-image = {
    description = "Clone and build the yattee-server image";
    after = ["docker.service" "network-online.target"];
    requires = ["docker.service"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.git pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      src=/var/lib/yattee-server/src
      mkdir -p "$src"
      if [ -d "$src/.git" ]; then
        git -C "$src" pull --ff-only || true
      else
        git clone --depth 1 https://github.com/yattee/yattee-server.git "$src"
      fi
      docker build -t yattee-server:local "$src"
    '';
  };

  virtualisation.oci-containers.containers.yattee-server = {
    image = "yattee-server:local";
    autoStart = true;
    ports = ["8080:8085"]; # host 8080 (already open) -> container's 8085
    volumes = [
      "yattee-data:/app/data" # DB + encryption keys
      "yattee-downloads:/downloads" # temp proxied video
    ];
    environment = {
      ADMIN_USERNAME = "admin";
      # INVIDIOUS_INSTANCE_URL = "http://192.168.1.50:3000";  # optional, add later
    };
    environmentFiles = ["/var/lib/yattee-server/secrets.env"]; # ADMIN_PASSWORD lives here
  };

  # Don't start the container until the image is built.
  systemd.services."docker-yattee-server" = {
    after = ["yattee-server-image.service"];
    requires = ["yattee-server-image.service"];
  };
}
