{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./homepage.nix
  ];

  # --- USER CONFIGURATION ---
  users.users.deathraymind = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = ["wheel" "nextcloud"];
    hashedPassword = "$6$X6ADCAYJr36.atJY$aOzF6Drf0YEq2ac3QnFFU3bhJZNuY/hX9Fux6dcJCeiQTNBK1F3oFKqqlhpUoKVJA34gfIWs0VkcO1051jn5d0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1p2OamHpIwYUh0mS3yj/CDmT01n4leoYCd/tuqMJHt deathraymind@gmail.com"
    ];
  };
  virtualisation.docker.enable = true;

  # 2. Define the Vaultwarden container
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      vaultwarden = {
        image = "vaultwarden/server:latest"; # Includes the Web Vault UI
        ports = [
          "8443:80" # Maps local port 8443 to container port 80
        ];
        volumes = [
          "/var/lib/vaultwarden:/data" # Persists your passwords/data on the host
        ];
        environment = {
          # Change this to the external URL your separate Caddy server will use
          DOMAIN = "https://vaultwarden.deathraymind.net";
          SIGNUPS_ALLOWED = "true"; # Turn to "false" after creating your account
        };
        autoStart = true;
      };
    };
  };
}
