{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.nodejs   # For running dev servers if needed
    pkgs.python312Packages.httpserver  # Optional simple server
  ];
}

