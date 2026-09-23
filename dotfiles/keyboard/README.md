# Ubuntu Keyboard Layer

Keyboard-first control layer for Ubuntu GNOME.

## Source of truth

All user-defined keyboard bindings live in:

    keybindings.conf

Do not manually edit GNOME's generated custom shortcuts.

## Apply changes

    ./apply.sh

## Remove this layer

    ./remove.sh

## Current bindings

### Applications

    SUPER+ENTER  Terminal
    SUPER+E      Files
    SUPER+B      Browser

### Workspaces

    SUPER+1 ... SUPER+9

### Windows

    SUPER+Q      Close
    SUPER+F      Maximize

### System

    SUPER+L      Lock

## Architecture

    keybindings.conf
            |
            v
        apply.sh
            |
            v
       GNOME settings
            |
            v
         Ubuntu

The config file is the source of truth.
