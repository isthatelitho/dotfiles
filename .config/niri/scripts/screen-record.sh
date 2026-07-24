#!/bin/bash
# Save this as ~/.local/bin/toggle-screen-record.sh
# Make it executable: chmod +x ~/.local/bin/toggle-screen-record.sh

RECORDINGS_DIR="$HOME/Videos/recordings"
RECORDING_PATTERN="gpu-screen-recorder.*-w screen"
STATE_FILE="/tmp/recording_state"

# Create recordings directory if it doesn't exist
mkdir -p "$RECORDINGS_DIR"

# Check if recording is already running
if pgrep -f "$RECORDING_PATTERN" > /dev/null; then
    # Stop recording
    pkill -f "$RECORDING_PATTERN"

    notify-send recording-stopped

    # Remove state file
    rm -f "$STATE_FILE"

else
    # Start recording
    FILENAME="$RECORDINGS_DIR/recording_$(date +%Y%m%d_%H%M%S).mp4"
    gpu-screen-recorder -w screen -s 1920x1080 -f 60 -a default_output -o "$FILENAME" &

    notify-send recording-started

    # Create state file
    echo "recording" > "$STATE_FILE"

fi
