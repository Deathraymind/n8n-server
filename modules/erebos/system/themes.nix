# themes.nix
{
  catppuccin-mocha = {
    base00 = "1e1e2e";
    base01 = "181825";
    base02 = "313244";
    base03 = "45475a";
    base04 = "585b70";
    base05 = "cdd6f4";
    base06 = "f5e0dc";
    base07 = "b4befe";
    base08 = "f38ba8";
    base09 = "fab387";
    base0A = "f9e2af";
    base0B = "a6e3a1";
    base0C = "94e2d5";
    base0D = "89b4fa";
    base0E = "cba6f7";
    base0F = "f2cdcd";
  };
  black-metal-mayhem = {
    base00 = "000000";
    base01 = "121212";
    base02 = "222222";
    base03 = "333333";
    base04 = "999999";
    base05 = "c1c1c1";
    base06 = "999999";
    base07 = "c1c1c1";
    base08 = "5f8787";
    base09 = "aaaaaa";
    base0A = "eecc6c";
    base0B = "f3ecd4";
    base0C = "aaaaaa";
    base0D = "888888";
    base0E = "999999";
    base0F = "444444";
  };
  github-dark-high-contrast = {
    base00 = "0a0c10";
    base01 = "272b33";
    base02 = "7a828e";
    base03 = "9ea7b3";
    base04 = "bdc4cc";
    base05 = "f0f3f6";
    base06 = "ffffff";
    base07 = "ffffff";
    base08 = "ffb757";
    base09 = "91cbff";
    base0A = "e09b13";
    base0B = "addcff";
    base0C = "72f088";
    base0D = "dbb7ff";
    base0E = "ff9492";
    base0F = "ffb1af";
  };

  ayu-dark = {
    base00 = "0b0e14";
    base01 = "131721";
    base02 = "202229";
    base03 = "3e4b59";
    base04 = "bfbdb6";
    base05 = "e6e1cf";
    base06 = "ece8db";
    base07 = "f2f0e7";
    base08 = "f07178";
    base09 = "ff8f40";
    base0A = "ffb454";
    base0B = "aad94c";
    base0C = "95e6cb";
    base0D = "59c2ff";
    base0E = "d2a6ff";
    base0F = "e6b450";
  };
  gruber-darker = {
    base00 = "181818"; # bg
    base01 = "282828"; # bg+1 (status bars, line highlight)
    base02 = "453d41"; # bg+2 (selection)
    base03 = "52494e"; # bg+4 (line numbers, invisibles)
    base04 = "95a99f"; # quartz (dark fg, status text)
    base05 = "e4e4ef"; # fg
    base06 = "f4f4ff"; # fg+1
    base07 = "f5f5f5"; # fg+2
    base08 = "f43841"; # red (errors, variables)
    base09 = "cc8c3c"; # brown (integers, constants)
    base0A = "ffdd33"; # yellow (keywords, search)
    base0B = "73c936"; # green (strings)
    base0C = "95a99f"; # quartz (cyan slot, types)
    base0D = "96a6c8"; # niagara (blue, functions)
    base0E = "9e95c7"; # wisteria (magenta slot)
    base0F = "c73c3f"; # red-1 (deprecated)
  };
  gruvbox = {
    base00 = "161616"; # bg
    base01 = "3c3836";
    base02 = "504945";
    base03 = "665c54";
    base04 = "bdae93";
    base05 = "d5c4a1"; # fg
    base06 = "ebdbb2";
    base07 = "fbf1c7";
    base08 = "fb4934"; # red
    base09 = "fe8019"; # orange
    base0A = "fabd2f"; # yellow
    base0B = "b8bb26"; # green
    base0C = "8ec07c"; # aqua
    base0D = "83a598"; # blue
    base0E = "d3869b"; # purple
    base0F = "d65d0e"; # dark orange
  };
  sagelight = {
    base00 = "f8f8f8";
    base01 = "e8e8e8";
    base02 = "d8d8d8";
    base03 = "b8b8b8";
    base04 = "585858";
    base05 = "383838";
    base06 = "282828";
    base07 = "181818";
    base08 = "fa8480";
    base09 = "ffaa61";
    base0A = "ffdc61";
    base0B = "a0d2c8";
    base0C = "a2d6f5";
    base0D = "a0a7d2";
    base0E = "c8a0d2";
    base0F = "d2b2a0";
  };
  oxocarbon-dark = {
    # --- Backgrounds & Layers ---
    base00 = "161616"; # Background (Darkest)
    base01 = "262626"; # Lighter Background (Status bars)
    base02 = "393939"; # Selection/Highlight (Dimmer gray)
    base03 = "525252"; # Comments/Muted text

    # --- Foreground & Typography ---
    base04 = "dde1e6"; # Dark Gray Text (Subtle)
    base05 = "f2f4f8"; # Main Body Text (Whiteish)
    base06 = "ffffff"; # Bright White (Headlines/Active)

    # --- Accents & Icons (The Colors) ---
    base07 = "08bdba"; # Teal / Cyan
    base08 = "3ddbd9"; # Bright Aqua (Neon)
    base09 = "78a9ff"; # Sky Blue (Main accent)
    base0A = "ee5396"; # Magenta / Pink (Warm)
    base0B = "33b1ff"; # Steel Blue (Professional)
    base0C = "ff7eb6"; # Pastel Pink / Rose
    base0D = "42be65"; # Oxocarbon Green (Success)
    base0E = "be95ff"; # Purple (Axiom Signature)
    base0F = "82cfff"; # Soft Light Blue
  };
  tokyo-night = {
    base00 = "1a1b26"; # Background
    base01 = "16161e"; # Black / Darker Background
    base02 = "24283b"; # Selection Background
    base03 = "414868"; # Comments
    base04 = "565f89"; # Darker Foreground
    base05 = "c0caf5"; # Foreground / Variables
    base06 = "a9b1d6"; # Light Foreground
    base07 = "cfc9c2"; # Very Light Foreground
    base08 = "f7768e"; # Red (Tags, Keywords)
    base09 = "ff9e64"; # Orange (Numbers, Booleans)
    base0A = "e0af68"; # Yellow (Functions)
    base0B = "9ece6a"; # Green (Strings)
    base0C = "7dcfff"; # Cyan (Regex, Operators)
    base0D = "7aa2f7"; # Blue (Functions, Titles)
    base0E = "bb9af7"; # Magenta (Control Keywords)
    base0F = "c0caf5"; # Extra (Variables)
  };

  tokyo-night-storm = {
    base00 = "24283b"; # Background (Storm)
    base01 = "1f2335"; # Darker Background
    base02 = "292e42"; # Selection Background
    base03 = "414868"; # Comments
    base04 = "565f89"; # Darker Foreground
    base05 = "c0caf5"; # Foreground
    base06 = "a9b1d6"; # Light Foreground
    base07 = "cfc9c2"; # Very Light Foreground
    base08 = "f7768e"; # Red
    base09 = "ff9e64"; # Orange
    base0A = "e0af68"; # Yellow
    base0B = "9ece6a"; # Green
    base0C = "7dcfff"; # Cyan
    base0D = "7aa2f7"; # Blue
    base0E = "bb9af7"; # Magenta
    base0F = "c0caf5"; # Variables
  };

  tokyo-night-light = {
    base00 = "e6e7ed"; # Background
    base01 = "d5d6db"; # Darker Background
    base02 = "cbccd1"; # Selection
    base03 = "6c6e75"; # Comments
    base04 = "4f525e"; # Darker Foreground
    base05 = "343b58"; # Foreground
    base06 = "40434f"; # Light Foreground
    base07 = "565a6e"; # Very Light Foreground
    base08 = "8c4351"; # Red
    base09 = "965027"; # Orange
    base0A = "8f5e15"; # Yellow
    base0B = "385f0d"; # Green
    base0C = "0f4b6e"; # Cyan
    base0D = "2959aa"; # Blue
    base0E = "5a3e8e"; # Magenta
    base0F = "343b58"; # Variables
  };
  synth-midnight-dark = {
    base00 = "050608"; # Background
    base01 = "1a1b1c"; # Darker Background
    base02 = "28292a"; # Selection
    base03 = "474849"; # Comments
    base04 = "a3a5a6"; # Darker Foreground
    base05 = "c1c3c4"; # Foreground
    base06 = "cfd1d2"; # Light Foreground
    base07 = "dddfe0"; # Very Light Foreground
    base08 = "b53b50"; # Red
    base09 = "ea770d"; # Orange
    base0A = "c9d364"; # Yellow
    base0B = "06ea61"; # Green
    base0C = "42fff9"; # Cyan
    base0D = "03aeff"; # Blue
    base0E = "ea5ce2"; # Magenta
    base0F = "cd6320"; # Variables
  };
}
