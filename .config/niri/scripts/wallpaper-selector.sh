#!/usr/bin/env bash
set -euo pipefail

# configuration
WALLPAPER_DIR="$HOME/Pictures/walls"
CACHE_DIR="$HOME/.cache/rofi-wallpaper"
THUMBNAIL_SIZE="480x480"
THUMB_DIR="$CACHE_DIR/thumbs-${THUMBNAIL_SIZE}"
SYMLINK="$CACHE_DIR/current_wallpaper"
ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"

# jobs
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
THUMB_QUALITY=85

TILED_SUBDIR="tiled"

# animated wallpaper (mpvpaper) config
MPVPAPER_OUTPUT="eDP-1"
# hwdec: use the GPU decoder instead of CPU software decoding (biggest single win)
# vo=gpu + bilinear scalers: cheap scaling instead of mpv's higher-quality (costlier) defaults
# framedrop=vo: let mpv drop frames instead of fighting to catch up
# interpolation=no: motion interpolation is pure overhead for a static-position wallpaper
# panscan=1.0: crop-to-fill instead of letterboxing, avoids extra compositing work
MPVPAPER_OPTS="no-audio loop hwdec=auto-safe vo=gpu scale=bilinear cscale=bilinear dscale=bilinear interpolation=no framedrop=vo panscan=1.0"
# optional hard fps cap for high-framerate source clips, e.g. "30". Empty = no cap.
MPVPAPER_FPS_CAP="24"
# -p/--auto-pause: mpvpaper stops rendering when the wallpaper is fully hidden
# (e.g. a fullscreen window on top) - real CPU/GPU savings for free
MPVPAPER_FLAGS="-p"
VIDEO_EXTS=(mp4 mkv webm mov m4v)

HAVE_MPVPAPER=0
HAVE_FFMPEG=0
HAVE_NOCTALIA=0

mkdir -p "$THUMB_DIR"

declare -A THUMB_PATH

is_video() {
    local ext="${1##*.}"
    ext="${ext,,}"
    local e
    for e in "${VIDEO_EXTS[@]}"; do
        [[ "$ext" == "$e" ]] && return 0
    done
    return 1
}

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

    if is_video "$img"; then
        ((HAVE_FFMPEG)) || return 0
        local w="${THUMBNAIL_SIZE%x*}" h="${THUMBNAIL_SIZE#*x}"
        ffmpeg -y -ss 00:00:01 -i "$img" -frames:v 1 \
            -vf "scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}" \
            "$thumb" -loglevel error 2>/dev/null
    else
        local size_hint=()
        case "${img,,}" in
            *.jpg|*.jpeg) size_hint=(-define "jpeg:size=${THUMBNAIL_SIZE%x*}x${THUMBNAIL_SIZE#*x}") ;;
        esac
        magick "${size_hint[@]}" "$img"[0] -strip -quality "$THUMB_QUALITY" -thumbnail "${THUMBNAIL_SIZE}^" -gravity center -extent "$THUMBNAIL_SIZE" "$thumb" 2>/dev/null
    fi
}

cleanup_orphaned_thumbnails() {
    local tmp_valid
    tmp_valid=$(mktemp)

    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \
        -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" -o -iname "*.mov" -o -iname "*.m4v" \) -print0 | \
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

wallpaper_mode() {
    local wallpaper="$1"
    case "$wallpaper" in
        "$WALLPAPER_DIR/$TILED_SUBDIR"/*) echo "tile" ;;
        *) echo "fill" ;;
    esac
}

apply_noctalia_colors() {
    local wallpaper="$1"

    ((HAVE_NOCTALIA)) || return 0

    local color_source="$wallpaper"
    if is_video "$wallpaper"; then
        # noctalia also needs a static image; reuse the already-generated thumbnail
        local thumb="${THUMB_PATH[$wallpaper]:-}"
        [[ -n "$thumb" && -f "$thumb" ]] || return 0
        color_source="$thumb"
    fi

    ( setsid noctalia msg wallpaper-set "$color_source" >/dev/null 2>&1 & disown ) &
}

set_wallpaper() {
    local wallpaper="$1"

    if is_video "$wallpaper"; then
        if ((! HAVE_MPVPAPER)); then
            notify-send "Wallpaper Selector" "Error: mpvpaper not found, can't set video wallpaper"
            exit 1
        fi

        pkill swaybg 2>/dev/null || true
        pkill mpvpaper 2>/dev/null || true
        # give the old layer-shell surface a moment to release before attaching a new one
        sleep 0.15

        local mpv_opts="$MPVPAPER_OPTS"
        [[ -n "$MPVPAPER_FPS_CAP" ]] && mpv_opts="$mpv_opts vf=fps=${MPVPAPER_FPS_CAP}"

        ( setsid mpvpaper $MPVPAPER_FLAGS -o "$mpv_opts" "$MPVPAPER_OUTPUT" "$wallpaper" >/dev/null 2>&1 & disown ) &
    else
        local mode
        mode=$(wallpaper_mode "$wallpaper")

        pkill mpvpaper 2>/dev/null || true
        pkill swaybg 2>/dev/null || true
        sleep 0.15

        ( setsid swaybg -i "$wallpaper" -m "$mode" >/dev/null 2>&1 & disown ) &
    fi

    ln -sf "$wallpaper" "$SYMLINK"

    apply_noctalia_colors "$wallpaper"
}

main() {
    for cmd in magick rofi swaybg python3; do
        command -v "$cmd" >/dev/null || {
            notify-send "Wallpaper Selector" "Error: $cmd not found"
            exit 1
        }
    done

    command -v mpvpaper >/dev/null && HAVE_MPVPAPER=1
    command -v ffmpeg >/dev/null && HAVE_FFMPEG=1
    command -v noctalia >/dev/null && HAVE_NOCTALIA=1

    local nice_cmd=(nice -n 19)
    command -v ionice >/dev/null && nice_cmd=(ionice -c3 nice -n 19)
    "${nice_cmd[@]}" bash -c "$(declare -f cleanup_orphaned_thumbnails); cleanup_orphaned_thumbnails" &

    mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \
        -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" -o -iname "*.mov" -o -iname "*.m4v" \) | sort)

    if ((! HAVE_MPVPAPER)); then
        # no mpvpaper on this system: silently drop video files from the list
        local filtered=()
        local w
        for w in "${WALLPAPERS[@]}"; do
            is_video "$w" || filtered+=("$w")
        done
        WALLPAPERS=("${filtered[@]}")
    fi

    [[ ${#WALLPAPERS[@]} -eq 0 ]] && { notify-send "Wallpaper Selector" "No wallpapers found in $WALLPAPER_DIR"; exit 1; }

    local current_wallpaper=""
    [[ -L "$SYMLINK" ]] && current_wallpaper=$(readlink -f "$SYMLINK")

    hash_all_paths

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

    if [[ -f "$ROFI_THEME" ]]; then
        SELECTED_NAME=$(printf "%b\n" "${entries[@]}" | rofi -dmenu -show-icons -i -p "Select Wallpaper" -theme "$ROFI_THEME") || exit 0
    else
        SELECTED_NAME=$(printf "%b\n" "${entries[@]}" | rofi -dmenu -show-icons -i -p "Select Wallpaper" \
            -theme-str 'window {width: 60%; height: 70%;}' \
            -theme-str 'listview {columns: 3; lines: 4;}' \
            -theme-str 'element {padding: 5px; orientation: vertical;}' \
            -theme-str 'element-icon {size: 10em;}') || exit 0
    fi

    SELECTED_NAME="${SELECTED_NAME#● }"
    SELECTED=$(printf "%s\n" "${WALLPAPERS[@]}" | grep -F "/$SELECTED_NAME" | head -n1)

    [[ -z "$SELECTED" ]] && { notify-send "Wallpaper Selector" "Error: Could not find selected wallpaper"; exit 1; }

    set_wallpaper "$SELECTED"
}

main "$@"
