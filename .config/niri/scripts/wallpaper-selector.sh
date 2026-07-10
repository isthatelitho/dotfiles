#!/usr/bin/env bash
set -euo pipefail

# configuration
WALLPAPER_DIR="$HOME/Pictures/walls"
CACHE_DIR="$HOME/.cache/rofi-wallpaper"
THUMBNAIL_SIZE="480x480"                       # square thumbnails
THUMB_DIR="$CACHE_DIR/thumbs-${THUMBNAIL_SIZE}" # size baked into path = auto cache-bust on change
SYMLINK="$CACHE_DIR/current_wallpaper"
ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"

# jobs
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
THUMB_QUALITY=85  # JPEG quality for thumbnails

# wallpapers living under this subfolder of WALLPAPER_DIR get -m tile instead of -m fill
TILED_SUBDIR="tiled"

mkdir -p "$THUMB_DIR"

# THUMB_PATH["/abs/path/to/img.jpg"] = "$THUMB_DIR/<md5(path)>.jpg"
declare -A THUMB_PATH

# Hash every wallpaper path in a single process instead of forking md5sum per file.
hash_all_paths() {
    local hash path
    while IFS=$'\t' read -r hash path; do
        THUMB_PATH["$path"]="$THUMB_DIR/${hash}.jpg"
    done < <(printf '%s\n' "${WALLPAPERS[@]}" | python3 -c '
import sys, hashlib
for line in sys.stdin:
    line = line.rstrip("\n")
    if line:
        print(hashlib.md5(line.encode()).hexdigest() + "\t" + line)
')
}

make_thumb() {
    local img="$1" thumb="$2"
    magick "$img"[0] -strip -quality "$THUMB_QUALITY" -resize "${THUMBNAIL_SIZE}^" -gravity center -extent "$THUMBNAIL_SIZE" "$thumb" 2>/dev/null
}

# Remove thumbnails whose source wallpaper no longer exists (also single-process hashing).
cleanup_orphaned_thumbnails() {
    local tmp_valid
    tmp_valid=$(mktemp)

    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) -print0 | \
        python3 -c '
import sys, hashlib
for chunk in sys.stdin.buffer.read().split(b"\x00"):
    if chunk:
        print(hashlib.md5(chunk).hexdigest() + ".jpg")
' > "$tmp_valid"

    comm -23 <(ls -1 "$THUMB_DIR" 2>/dev/null | sort) <(sort "$tmp_valid") | while IFS= read -r stale; do
        rm -f "$THUMB_DIR/$stale"
    done

    rm -f "$tmp_valid"
}

# figure out which -m mode a given wallpaper should use
wallpaper_mode() {
    local wallpaper="$1"
    case "$wallpaper" in
        "$WALLPAPER_DIR/$TILED_SUBDIR"/*) echo "tile" ;;
        *) echo "fill" ;;
    esac
}

# apply the chosen wallpaper
set_wallpaper() {
    local wallpaper="$1"
    local mode
    mode=$(wallpaper_mode "$wallpaper")

    pkill swaybg 2>/dev/null || true
    ( setsid swaybg -i "$wallpaper" -m "$mode" >/dev/null 2>&1 & disown ) &

    ln -sf "$wallpaper" "$SYMLINK"
}

# execution
main() {
    for cmd in magick rofi swaybg python3; do
        command -v "$cmd" >/dev/null || {
            notify-send "Wallpaper Selector" "Error: $cmd not found"
            exit 1
        }
    done

    nice -n 19 bash -c "$(declare -f cleanup_orphaned_thumbnails); cleanup_orphaned_thumbnails" &

    # Find all wallpapers (swaybg has no video support, so images only)
    mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | sort)

    [[ ${#WALLPAPERS[@]} -eq 0 ]] && { notify-send "Wallpaper Selector" "No wallpapers found in $WALLPAPER_DIR"; exit 1; }

    # Get current wallpaper
    local current_wallpaper=""
    [[ -L "$SYMLINK" ]] && current_wallpaper=$(readlink -f "$SYMLINK")

    # Resolve all thumbnail paths in one shot
    hash_all_paths

    # Generate any missing thumbnails, bounded to MAX_PARALLEL_JOBS concurrent jobs.
    # wait -n frees a slot as soon as ANY job finishes, instead of waiting on a
    # specific (possibly slow) one, keeping all cores busy.
    local running=0
    for img in "${WALLPAPERS[@]}"; do
        thumb="${THUMB_PATH[$img]}"
        if [[ ! -f "$thumb" ]]; then
            make_thumb "$img" "$thumb" &
            running=$((running + 1))
            if ((running >= MAX_PARALLEL_JOBS)); then
                wait -n
                running=$((running - 1))
            fi
        fi
    done
    wait

    # Build rofi entries
    local entries=()
    for img in "${WALLPAPERS[@]}"; do
        local base
        base=$(basename "$img")
        local thumb="${THUMB_PATH[$img]}"

        if [[ "$img" == "$current_wallpaper" ]]; then
            entries+=("● ${base}\x00icon\x1f${thumb}")
        else
            entries+=("${base}\x00icon\x1f${thumb}")
        fi
    done

    # Show rofi selector
    if [[ -f "$ROFI_THEME" ]]; then
        SELECTED_NAME=$(printf "%b\n" "${entries[@]}" | rofi -dmenu -show-icons -i -p "Select Wallpaper" -theme "$ROFI_THEME") || exit 0
    else
        SELECTED_NAME=$(printf "%b\n" "${entries[@]}" | rofi -dmenu -show-icons -i -p "Select Wallpaper" \
            -theme-str 'window {width: 60%; height: 70%;}' \
            -theme-str 'listview {columns: 3; lines: 4;}' \
            -theme-str 'element {padding: 5px; orientation: vertical;}' \
            -theme-str 'element-icon {size: 10em;}') || exit 0
    fi

    # Remove marker and find selected wallpaper
    SELECTED_NAME="${SELECTED_NAME#● }"
    SELECTED=$(printf "%s\n" "${WALLPAPERS[@]}" | grep -F "/$SELECTED_NAME" | head -n1)

    [[ -z "$SELECTED" ]] && { notify-send "Wallpaper Selector" "Error: Could not find selected wallpaper"; exit 1; }

    # Apply wallpaper
    set_wallpaper "$SELECTED"
}

main "$@"
