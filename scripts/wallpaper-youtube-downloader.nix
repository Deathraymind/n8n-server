{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    yt-dlp
    ffmpeg
  ];

  shellHook = ''
    # Define the target directory
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    mkdir -p "$WALLPAPER_DIR"

    echo "--- 4K Wallpaper Downloader Loaded ---"
    echo "Files will be saved to: $WALLPAPER_DIR"
    echo "Usage: dl4k 'URL'"

    dl4k() {
      if [ -z "$1" ]; then
        echo "Error: Please provide a YouTube URL."
        return 1
      fi

      URL="$1"

      # 1. Get the filename first to use in our path
      RAW_NAME=$(yt-dlp --get-filename -o "%(title)s [%(id)s].mp4" "$URL")
      FULL_RAW_PATH="$WALLPAPER_DIR/$RAW_NAME"

      echo "Downloading 4K MP4 to $WALLPAPER_DIR..."

      # 2. Download directly to the Wallpapers folder
      yt-dlp -f "bestvideo[height<=2160]+bestaudio/best" \
             --merge-output-format mp4 \
             -o "$FULL_RAW_PATH" \
             "$URL"

      # 3. Define the cropped filename and path
      FINAL_NAME="''${RAW_NAME%.*}_16x9.mp4"
      FULL_FINAL_PATH="$WALLPAPER_DIR/$FINAL_NAME"

      echo "Cropping to 16:9: $FULL_FINAL_PATH"

      # 4. Run ffmpeg on the file in that specific directory
      ffmpeg -i "$FULL_RAW_PATH" -vf "crop=ih*16/9:ih" -c:a copy "$FULL_FINAL_PATH"

      echo "Success! Your 16:9 wallpaper is ready in ~/Pictures/Wallpapers"
    }
  '';
}
