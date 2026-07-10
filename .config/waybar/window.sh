#!/usr/bin/env bash

MAX_LEN=50

print_window() {

window=$(niri msg --json focused-window)

# focused-window returns "null" (literal JSON null) when nothing is focused
if [[ "$window" == "null" ]]; then
    ws=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused==true) | .idx')
    echo "{\"text\":\"[Desktop = Workspace $ws]\"}"
    return
fi

title=$(jq -r '.title' <<< "$window")
app_id=$(jq -r '.app_id' <<< "$window")

if [[ "$title" == "null" || -z "$title" ]]; then
    ws=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused==true) | .idx')
    echo "{\"text\":\"[Desktop = Workspace $ws]\"}"
    return
fi

# Calculate safe title length (reserve space for brackets + app_id)
reserve=$(( ${#app_id} + 7 ))
limit=$(( MAX_LEN - reserve ))

if (( ${#title} > limit )); then
    title="${title:0:$((limit-3))}.."
fi

echo "{\"text\":\"[$app_id = $title]\"}"

}

print_window

niri msg --json event-stream |
while read -r event
do
    case "$event" in
        *WindowFocusChanged*|*WindowOpenedOrChanged*|*WindowClosed*|*WorkspaceActivated*|*WorkspaceActiveWindowChanged*|*WindowsChanged*|*WorkspacesChanged*)
            print_window
        ;;
    esac
done
