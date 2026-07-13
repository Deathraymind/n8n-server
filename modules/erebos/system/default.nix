{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./desktop-logic.nix
    ./steam.nix
    ./stylix.nix
    ./defaultApplications.nix
    ./cachy.nix
    ./autologin.nix
    ./ollama.nix
    ./tmux.nix
    ./screenshot.nix
  ];
}
