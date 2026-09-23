#!/usr/bin/env bash

set -euo pipefail

WM_SCHEMA="org.gnome.desktop.wm.keybindings"
MEDIA_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"

echo
echo "=============================================="
echo " Ubuntu Keyboard Layer Status"
echo "=============================================="
echo

echo "Config:"
echo "  $HOME/dotfiles/keyboard/keybindings.conf"

echo
echo "Workspace bindings:"
for n in {1..9}; do
    printf "  Super+%s -> " "$n"
    gsettings get "$WM_SCHEMA" "switch-to-workspace-$n"
done

echo
echo "Window bindings:"
echo "  Close:"
gsettings get "$WM_SCHEMA" close

echo "  Maximize:"
gsettings get "$WM_SCHEMA" maximize

echo
echo "Lock:"
gsettings get "$MEDIA_SCHEMA" screensaver

echo
echo "Custom shortcuts:"
gsettings get "$MEDIA_SCHEMA" custom-keybindings

echo
echo "=============================================="
