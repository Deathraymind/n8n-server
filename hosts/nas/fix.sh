#!/usr/bin/env bash

FILE="/home/deathraymind/n8n-server/hosts/nas/filebrowser-theme.css"

if [ ! -f "$FILE" ]; then
    echo "Error: $FILE not found."
    exit 1
fi

echo "Patching $FILE for full Oxocarbon Black consistency..."

# -------------------------------------------------------------------
# Add new Oxocarbon variables
# -------------------------------------------------------------------

perl -0pi -e 's/--moon-grey:\s*#f2f4f8;/--moon-grey: #f2f4f8;\n\n    --surfaceElevated: #2c2c2c;\n    --surfaceOverlay: #1f1f1f;\n    --surfaceAccent: #393939;\n\n    --focus: #5f6373;\n\n    --green: #42be65;\n    --green-light: #6fdc8c;\n\n    --overlay-dark: rgba\(0, 0, 0, 0.6\);\n    --overlay-light: rgba\(0, 0, 0, 0.3\);\n\n    --preview-bg: rgba\(8, 9, 12, 0.9\);\n    --preview-bg-blur: rgba\(8, 9, 12, 0.8\);\n\n    --selection-bg: #393939;\n    --shell-bg: #2c2c2c;\n\n    --hover-blue: rgba\(120, 169, 255, 0.12\);/g' "$FILE"

# -------------------------------------------------------------------
# Replace remaining hardcoded colors
# -------------------------------------------------------------------

declare -A replacements=(
    ["rgba(0, 0, 0, 0.6)"]="var(--overlay-dark)"
    ["rgba(0, 0, 0, 0.3)"]="var(--overlay-light)"
    ["rgba(142, 178, 255, 0.15)"]="var(--hover-blue)"
    ["rgba(146, 154, 201, 0.1)"]="var(--hover-blue)"
    ["#2B354B"]="var(--surfaceAccent)"
    ["#30364c"]="var(--shell-bg)"
    ["#30364C"]="var(--shell-bg)"
    ["#5f6373"]="var(--focus)"
    ["#147A41"]="var(--green)"
    ["#84c77d"]="var(--green-light)"
    ["rgba(8, 9, 12, 0.9)"]="var(--preview-bg)"
    ["rgba(8, 9, 12, 0.8)"]="var(--preview-bg-blur)"
)

for search in "${!replacements[@]}"; do
    replace="${replacements[$search]}"
    sed -i "s|$search|$replace|g" "$FILE"
done

echo "Done."
echo "Your theme should now be much closer to a complete Oxocarbon Black implementation."
