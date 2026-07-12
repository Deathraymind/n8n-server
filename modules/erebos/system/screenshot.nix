{pkgs, ...}: let
  tesseract-ocr = pkgs.tesseract.override {};

  hypersnip = pkgs.writeShellScriptBin "hypersnip" ''
    # 1. Capture image
    IMG="/tmp/snip.png"
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$IMG"

    # 2. Check if file is empty (user hit ESC)
    [ ! -s "$IMG" ] && exit 0

    # 3. Open Swappy to edit
    ${pkgs.swappy}/bin/swappy -f "$IMG" -o "$IMG"

  '';
in {
  environment.systemPackages = with pkgs; [
    grim
    slurp
    swappy
    kitty
    hypersnip
    wl-clipboard
  ];
}
