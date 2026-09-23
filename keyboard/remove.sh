#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.state/gnome-state.sh"

WM_SCHEMA="org.gnome.desktop.wm.keybindings"
MEDIA_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"

[[ -f "$STATE_FILE" ]] || {
    echo
    echo "No saved keyboard-layer state exists."
    echo "Nothing to remove."
    echo
    exit 0
}

# shellcheck disable=SC1090
source "$STATE_FILE"

echo
echo "=============================================="
echo " Removing Ubuntu Keyboard Layer"
echo "=============================================="
echo

gsettings set "$WM_SCHEMA" switch-to-workspace-1 "$BACKUP_WORKSPACE_1"
gsettings set "$WM_SCHEMA" switch-to-workspace-2 "$BACKUP_WORKSPACE_2"
gsettings set "$WM_SCHEMA" switch-to-workspace-3 "$BACKUP_WORKSPACE_3"
gsettings set "$WM_SCHEMA" switch-to-workspace-4 "$BACKUP_WORKSPACE_4"
gsettings set "$WM_SCHEMA" switch-to-workspace-5 "$BACKUP_WORKSPACE_5"
gsettings set "$WM_SCHEMA" switch-to-workspace-6 "$BACKUP_WORKSPACE_6"
gsettings set "$WM_SCHEMA" switch-to-workspace-7 "$BACKUP_WORKSPACE_7"
gsettings set "$WM_SCHEMA" switch-to-workspace-8 "$BACKUP_WORKSPACE_8"
gsettings set "$WM_SCHEMA" switch-to-workspace-9 "$BACKUP_WORKSPACE_9"

gsettings set "$WM_SCHEMA" close "$BACKUP_CLOSE"
gsettings set "$WM_SCHEMA" maximize "$BACKUP_MAXIMIZE"
gsettings set "$MEDIA_SCHEMA" screensaver "$BACKUP_SCREENSAVER"
gsettings set "$MEDIA_SCHEMA" custom-keybindings "$BACKUP_CUSTOM"

# Remove our custom shortcut definitions.
for id in \
    ubuntu-keyboard-terminal \
    ubuntu-keyboard-files \
    ubuntu-keyboard-browser
do
    path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$id/"
    schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path"

    gsettings reset "$schema" name 2>/dev/null || true
    gsettings reset "$schema" command 2>/dev/null || true
    gsettings reset "$schema" binding 2>/dev/null || true
done

echo
echo "Keyboard layer removed."
echo
echo "GNOME's previous state has been restored."
echo
