#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/keybindings.conf"
STATE_DIR="$SCRIPT_DIR/.state"
STATE_FILE="$STATE_DIR/gnome-state.sh"

WM_SCHEMA="org.gnome.desktop.wm.keybindings"
WM_PREFS_SCHEMA="org.gnome.desktop.wm.preferences"
MUTTER_SCHEMA="org.gnome.mutter"
MEDIA_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
SHELL_SCHEMA="org.gnome.shell.keybindings"
DOCK_SCHEMA="org.gnome.shell.extensions.dash-to-dock"

CUSTOM_BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
CUSTOM_PREFIX="${CUSTOM_BASE}/ubuntu-keyboard-"

die() {
    echo
    echo "ERROR: $*" >&2
    echo
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_command gsettings
require_command python3

[[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"

mkdir -p "$STATE_DIR"

# ============================================================
# Verify required GNOME schemas
# ============================================================

gsettings list-keys "$WM_SCHEMA" >/dev/null 2>&1 \
    || die "GNOME WM keybinding schema is unavailable."

gsettings list-keys "$WM_PREFS_SCHEMA" >/dev/null 2>&1 \
    || die "GNOME WM preferences schema is unavailable."

gsettings list-keys "$MUTTER_SCHEMA" >/dev/null 2>&1 \
    || die "GNOME Mutter schema is unavailable."

gsettings list-keys "$MEDIA_SCHEMA" >/dev/null 2>&1 \
    || die "GNOME media-key schema is unavailable."

gsettings list-keys "$SHELL_SCHEMA" >/dev/null 2>&1 \
    || die "GNOME Shell keybinding schema is unavailable."

gsettings list-keys "$DOCK_SCHEMA" >/dev/null 2>&1 \
    || die "Ubuntu Dock schema is unavailable."

# ============================================================
# Parse configuration
# ============================================================

declare -A ACTIONS=()

while IFS= read -r line || [[ -n "$line" ]]; do

    # Remove comments.
    line="${line%%#*}"

    # Trim whitespace.
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Ignore blank lines.
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        key="$(echo "${BASH_REMATCH[1]}" | xargs)"
        action="$(echo "${BASH_REMATCH[2]}" | xargs)"

        [[ -n "$key" ]] || die "Empty keybinding."
        [[ -n "$action" ]] || die "Empty action for $key"

        ACTIONS["$key"]="$action"
    else
        die "Invalid config line: $line"
    fi

done < "$CONFIG_FILE"

# ============================================================
# Convert our readable key syntax to GNOME syntax
# ============================================================

gnome_key() {
    local key="$1"
    local result=""
    local part

    IFS='+' read -ra parts <<< "$key"

    for part in "${parts[@]}"; do
        case "$part" in
            SUPER)
                result+="<Super>"
                ;;
            CTRL)
                result+="<Control>"
                ;;
            ALT)
                result+="<Alt>"
                ;;
            SHIFT)
                result+="<Shift>"
                ;;
            ENTER)
                result+="Return"
                ;;
            ESC)
                result+="Escape"
                ;;
            TAB)
                result+="Tab"
                ;;
            SPACE)
                result+="space"
                ;;
            UP)
                result+="Up"
                ;;
            DOWN)
                result+="Down"
                ;;
            LEFT)
                result+="Left"
                ;;
            RIGHT)
                result+="Right"
                ;;
            PAGEUP)
                result+="Page_Up"
                ;;
            PAGEDOWN)
                result+="Page_Down"
                ;;
            *)
                result+="$(echo "$part" | tr '[:upper:]' '[:lower:]')"
                ;;
        esac
    done

    echo "$result"
}

# ============================================================
# Safe GNOME array parser
# ============================================================

gsettings_array_to_python() {
    local value="$1"

    if [[ "$value" == "@as []" ]]; then
        echo "[]"
        return
    fi

    python3 - "$value" <<'PY'
import ast
import sys

value = sys.argv[1]
parsed = ast.literal_eval(value)

if not isinstance(parsed, list):
    raise SystemExit("Expected a list from gsettings")

print(repr(parsed))
PY
}

# ============================================================
# Backup exact original state
# ============================================================

if [[ ! -f "$STATE_FILE" ]]; then

    echo
    echo "Creating keyboard-layer state backup..."

    {
        echo "# Ubuntu Keyboard Layer state backup"
        echo "# Created before first keyboard-layer installation."
        echo

        printf 'BACKUP_DYNAMIC_WORKSPACES=%q\n' \
            "$(gsettings get "$MUTTER_SCHEMA" dynamic-workspaces)"

        printf 'BACKUP_NUM_WORKSPACES=%q\n' \
            "$(gsettings get "$WM_PREFS_SCHEMA" num-workspaces)"

        printf 'BACKUP_CLOSE=%q\n' \
            "$(gsettings get "$WM_SCHEMA" close)"

        printf 'BACKUP_MAXIMIZE=%q\n' \
            "$(gsettings get "$WM_SCHEMA" maximize)"

        printf 'BACKUP_TOGGLE_MAXIMIZED=%q\n' \
            "$(gsettings get "$WM_SCHEMA" toggle-maximized)"

        printf 'BACKUP_SCREENSAVER=%q\n' \
            "$(gsettings get "$MEDIA_SCHEMA" screensaver)"

        printf 'BACKUP_CUSTOM=%q\n' \
            "$(gsettings get "$MEDIA_SCHEMA" custom-keybindings)"

        printf 'BACKUP_DOCK_HOT_KEYS=%q\n' \
            "$(gsettings get "$DOCK_SCHEMA" hot-keys)"

        for n in {1..10}; do
            if gsettings list-keys "$DOCK_SCHEMA" | grep -qx "app-hotkey-$n"; then
                printf 'BACKUP_DOCK_APP_HOTKEY_%s=%q\n' \
                    "$n" \
                    "$(gsettings get "$DOCK_SCHEMA" "app-hotkey-$n")"
            fi

            if gsettings list-keys "$DOCK_SCHEMA" | grep -qx "app-shift-hotkey-$n"; then
                printf 'BACKUP_DOCK_APP_SHIFT_HOTKEY_%s=%q\n' \
                    "$n" \
                    "$(gsettings get "$DOCK_SCHEMA" "app-shift-hotkey-$n")"
            fi
        done

    } > "$STATE_FILE"

    chmod 600 "$STATE_FILE"

    echo "State backup: $STATE_FILE"
fi

# ============================================================
# Output header
# ============================================================

echo
echo "=============================================="
echo " Ubuntu Keyboard Layer"
echo "=============================================="
echo
echo "Config: $CONFIG_FILE"
echo

# ============================================================
# Fixed 10-workspace model
# ============================================================

# Use GNOME's native dynamic workspace model.
#
# GNOME keeps an empty workspace available at the end and
# removes empty workspaces as they become unused.
gsettings set "$MUTTER_SCHEMA" dynamic-workspaces true

# GNOME requires a baseline workspace count. With dynamic
# workspaces enabled, this is not a fixed 10-workspace limit.
gsettings set "$WM_PREFS_SCHEMA" num-workspaces 2

echo "  system  dynamic workspaces -> enabled"

# ============================================================
# Workspace switching
# ============================================================

for n in {1..9}; do
    key="SUPER+$n"
    action="workspace:$n"

    if [[ "${ACTIONS[$key]:-}" == "$action" ]]; then
        binding="$(gnome_key "$key")"

        gsettings set \
            "$WM_SCHEMA" \
            "switch-to-workspace-$n" \
            "['$binding']"

        echo "  native  $key -> workspace $n"
    fi
done

# Super+0 means GNOME's current last workspace.
if [[ "${ACTIONS[SUPER+0]:-}" == "workspace:last" ]]; then
    binding="$(gnome_key "SUPER+0")"

    gsettings set \
        "$WM_SCHEMA" \
        "switch-to-workspace-last" \
        "['$binding']"

    echo "  native  SUPER+0 -> workspace 10 / last"
fi

# ============================================================
# Move current window to workspace
# ============================================================

for n in {1..9}; do
    key="SUPER+SHIFT+$n"
    action="move-to-workspace:$n"

    if [[ "${ACTIONS[$key]:-}" == "$action" ]]; then
        binding="$(gnome_key "$key")"

        gsettings set \
            "$WM_SCHEMA" \
            "move-to-workspace-$n" \
            "['$binding']"

        echo "  native  $key -> move window to workspace $n"
    fi
done

if [[ "${ACTIONS[SUPER+SHIFT+0]:-}" == "move-to-workspace:last" ]]; then
    binding="$(gnome_key "SUPER+SHIFT+0")"

    gsettings set \
        "$WM_SCHEMA" \
        "move-to-workspace-last" \
        "['$binding']"

    echo "  native  SUPER+SHIFT+0 -> move window to workspace 10 / last"
fi

# ============================================================
# Window controls
# ============================================================

if [[ "${ACTIONS[SUPER+W]:-}" == "close" ]]; then
    binding="$(gnome_key "SUPER+W")"

    gsettings set \
        "$WM_SCHEMA" \
        close \
        "['$binding']"

    echo "  native  SUPER+W -> close"
fi

# Disable the old Super+Q binding that we previously created.
gsettings set "$WM_SCHEMA" close "['<Super>w']"

if [[ "${ACTIONS[SUPER+F]:-}" == "toggle-maximized" ]]; then
    binding="$(gnome_key "SUPER+F")"

    gsettings set \
        "$WM_SCHEMA" \
        toggle-maximized \
        "['$binding']"

    echo "  native  SUPER+F -> toggle maximize"
fi

# Remove Super+F from the one-way maximize action.
gsettings set "$WM_SCHEMA" maximize "[]"

# ============================================================
# Lock
# ============================================================

if [[ "${ACTIONS[SUPER+L]:-}" == "lock" ]]; then
    binding="$(gnome_key "SUPER+L")"

    gsettings set \
        "$MEDIA_SCHEMA" \
        screensaver \
        "['$binding']"

    echo "  native  SUPER+L -> lock"
fi

# ============================================================
# Disable GNOME application-number switching
# ============================================================

for n in {1..9}; do
    if gsettings list-keys "$SHELL_SCHEMA" | grep -qx "switch-to-application-$n"; then
        gsettings set "$SHELL_SCHEMA" "switch-to-application-$n" "[]"
    fi
done

echo "  system  GNOME application-number shortcuts disabled"

# ============================================================
# Disable Ubuntu Dock Super-number shortcuts.
#
# This is critical because the Dock otherwise competes with
# our workspace bindings.
# ============================================================

gsettings set "$DOCK_SCHEMA" hot-keys false

for n in {1..10}; do

    if gsettings list-keys "$DOCK_SCHEMA" | grep -qx "app-hotkey-$n"; then
        gsettings set "$DOCK_SCHEMA" "app-hotkey-$n" "[]"
    fi

    if gsettings list-keys "$DOCK_SCHEMA" | grep -qx "app-shift-hotkey-$n"; then
        gsettings set "$DOCK_SCHEMA" "app-shift-hotkey-$n" "[]"
    fi

done

echo "  system  Ubuntu Dock Super-number shortcuts disabled"

# ============================================================
# Custom application shortcuts
# ============================================================

declare -a OUR_PATHS=()

add_custom() {
    local id="$1"
    local name="$2"
    local command="$3"
    local key="$4"

    local path="${CUSTOM_BASE}/${id}/"
    local binding

    binding="$(gnome_key "$key")"

    gsettings set \
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" \
        name \
        "$name"

    gsettings set \
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" \
        command \
        "$command"

    gsettings set \
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" \
        binding \
        "$binding"

    OUR_PATHS+=("$path")

    echo "  custom  $key -> $command"
}

if [[ "${ACTIONS[SUPER+ENTER]:-}" == "terminal" ]]; then
    add_custom \
        "ubuntu-keyboard-terminal" \
        "Ubuntu Keyboard - Terminal" \
        "x-terminal-emulator" \
        "SUPER+ENTER"
fi

if [[ "${ACTIONS[SUPER+E]:-}" == "files" ]]; then
    add_custom \
        "ubuntu-keyboard-files" \
        "Ubuntu Keyboard - Files" \
        "nautilus" \
        "SUPER+E"
fi

if [[ "${ACTIONS[SUPER+B]:-}" == "browser" ]]; then
    add_custom \
        "ubuntu-keyboard-browser" \
        "Ubuntu Keyboard - Browser" \
        "xdg-open https://www.google.com" \
        "SUPER+B"
fi

# ============================================================
# Register our custom shortcuts without destroying unrelated
# GNOME custom shortcuts.
# ============================================================

CURRENT_RAW="$(gsettings get "$MEDIA_SCHEMA" custom-keybindings)"
CURRENT_PY="$(gsettings_array_to_python "$CURRENT_RAW")"

NEW_CUSTOM="$(
    python3 - "$CURRENT_PY" "${OUR_PATHS[@]}" <<'PY'
import ast
import sys

current = ast.literal_eval(sys.argv[1])
ours = set(sys.argv[2:])

managed_prefix = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ubuntu-keyboard-"

result = [
    path for path in current
    if not path.startswith(managed_prefix)
]

result.extend(sorted(ours))

print(repr(result))
PY
)"

gsettings set "$MEDIA_SCHEMA" custom-keybindings "$NEW_CUSTOM"

# ============================================================
# Delete stale managed custom shortcut definitions.
# ============================================================

python3 - "$CURRENT_PY" "$NEW_CUSTOM" <<'PY'
import ast
import subprocess
import sys

old = set(ast.literal_eval(sys.argv[1]))
new = set(ast.literal_eval(sys.argv[2]))

managed_prefix = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ubuntu-keyboard-"

stale = [
    path for path in old
    if path.startswith(managed_prefix) and path not in new
]

for path in stale:
    schema = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path}"

    for key in ("name", "command", "binding"):
        subprocess.run(
            ["gsettings", "reset", schema, key],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
PY

# ============================================================
# Disable Super-alone Activities Overview
# ============================================================
#
# Ubuntu/GNOME uses Mutter's overlay-key for the bare Super key.
# We want Super to be a modifier for our keyboard layer, not a
# standalone overview launcher.
# ============================================================

gsettings set org.gnome.mutter overlay-key 'Super_L'

# Also remove the Shell keybinding for toggling the overview.
# This prevents another Shell-level overview binding from
# competing with our keyboard layer.
gsettings set org.gnome.shell.keybindings toggle-overview "[]"

echo "  system  Super-alone Activities Overview -> disabled"

echo
echo "=============================================="
echo " Keyboard layer applied successfully."
echo "=============================================="
echo
echo "Workspace model:"
echo "  Dynamic workspaces enabled"
echo
echo "Navigation:"
echo "  Super+1..9 = switch to existing workspace"
echo "  Super+0    = switch to current last workspace"
echo
echo "Window movement:"
echo "  Super+Shift+1..9 = move window to workspace"
echo "  Super+Shift+0    = move window to last workspace"
echo
echo "Window controls:"
echo "  Super+W = close"
echo "  Super+F = maximize / restore"
echo
