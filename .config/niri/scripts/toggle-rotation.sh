#!/bin/bash

current=$(niri msg outputs | grep -A 20 "eDP-1" | grep "Transform:" | awk '{print $2}')

echo "Current transform: '$current'" >&2

if [ "$current" = "normal" ]; then
    echo "Rotating to 270" >&2
    niri msg output eDP-1 transform 270
else
    echo "Rotating to normal" >&2
    niri msg output eDP-1 transform normal
fi
