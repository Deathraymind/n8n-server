{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python312
    python312Packages.pip
    gcc12 
    python312Packages.torch
    ffmpeg
  ];

  # Optional: ROCm if you're on GPU
  shellHook = ''
    export HSA_OVERRIDE_GFX_VERSION=10.3.0
    python3 -m venv .venv
    source .venv/bin/activate
    pip install openai-whisper fastapi uvicorn
  '';
}

