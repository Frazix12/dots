#!/usr/bin/env bash

# Wallpaper directory
WALLPAPER_DIR="$HOME/Pictures/wall"

# Check if wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Error: Wallpaper directory does not exist" -u critical
    echo "Error: Wallpaper directory $WALLPAPER_DIR does not exist"
    exit 1
fi

# Check if matugen is installed
if ! command -v matugen &> /dev/null; then
    notify-send "Wallpaper Picker" "Error: matugen is not installed" -u critical
    echo "Error: matugen is not installed"
    exit 1
fi

# Get list of image files (common image formats)
mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -printf "%f\n" | sort)

# Check if any wallpapers found
if [ ${#wallpapers[@]} -eq 0 ]; then
    notify-send "Wallpaper Picker" "No wallpapers found in $WALLPAPER_DIR" -u normal
    echo "Error: No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# Create a temporary file with wallpaper paths for rofi
temp_file=$(mktemp)
for wallpaper in "${wallpapers[@]}"; do
    echo -e "$wallpaper\x00icon\x1f$WALLPAPER_DIR/$wallpaper" >> "$temp_file"
done

# Display wallpapers in rofi with image preview and get selection
selected=$(cat "$temp_file" | rofi -dmenu -i -p "Select Wallpaper" -show-icons)

# Clean up temporary file
rm "$temp_file"

# Check if user made a selection
if [ -z "$selected" ]; then
    echo "No wallpaper selected"
    exit 0
fi

# Full path to selected wallpaper
wallpaper_path="$WALLPAPER_DIR/$selected"

# Apply wallpaper using matugen
echo "Applying wallpaper: $selected"
matugen image "$wallpaper_path"

if [ $? -eq 0 ]; then
    notify-send "Wallpaper Picker" "Wallpaper applied: $selected" -i "$wallpaper_path"
    echo "Wallpaper applied successfully!"
else
    notify-send "Wallpaper Picker" "Failed to apply wallpaper" -u critical
    echo "Error: Failed to apply wallpaper"
    exit 1
fi