#!/bin/bash
# ── volume.sh ─────────────────────────────────────────────
# Description: Shows current audio volume with ASCII bar + tooltip
# Usage: Waybar `custom/volume` every 1s
# Dependencies: wpctl, awk, seq, printf
# ───────────────────────────────────────────────────────────

vol_line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)

# Get raw volume and convert to int (no bc needed, awk does the math)
vol_raw=$(echo "$vol_line" | awk '{ print $2 }')
vol_int=$(awk -v v="$vol_raw" 'BEGIN { printf "%d", (v * 100) }')
[ -z "$vol_int" ] && vol_int=0

# Check mute status
if echo "$vol_line" | grep -q MUTED; then
  is_muted=true
else
  is_muted=false
fi

# Get default sink description (human-readable)
sink=$(wpctl status | awk '/Sinks:/,/Sources:/' | grep '\*' | cut -d'.' -f2- | sed 's/^\s*//; s/\[.*//')

# Icon logic (Nerd Font glyphs — muted / low / medium / high)
if [ "$is_muted" = true ]; then
  icon="󰝟"
  vol_int=0
elif [ "$vol_int" -lt 1 ]; then
  icon="󰸈"
elif [ "$vol_int" -lt 34 ]; then
  icon="󰕿"
elif [ "$vol_int" -lt 67 ]; then
  icon="󰖀"
else
  icon="󰕾"
fi

# ASCII bar
filled=$((vol_int / 10))
empty=$((10 - filled))
bar=$(printf '█%.0s' $(seq 1 "$filled" 2>/dev/null))
pad=$(printf '░%.0s' $(seq 1 "$empty" 2>/dev/null))
ascii_bar="[$bar$pad]"

# Color logic
if [ "$is_muted" = true ] || [ "$vol_int" -lt 10 ]; then
  fg="#bf616a" # red
elif [ "$vol_int" -lt 50 ]; then
  fg="#fab387" # orange
else
  fg="#56b6c2" # cyan
fi

# Tooltip text
if [ "$is_muted" = true ]; then
  tooltip="Audio: Muted\nOutput: $sink"
else
  tooltip="Audio: $vol_int%\nOutput: $sink"
fi

# Final JSON output
echo "{\"text\":\"<span foreground='$fg'>$icon $ascii_bar $vol_int%</span>\",\"tooltip\":\"$tooltip\"}"
