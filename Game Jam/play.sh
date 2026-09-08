#!/usr/bin/env sh
# Portable launcher for Linux and macOS. It intentionally uses the user's
# Godot installation; local .runtime folders are optional and untracked.
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v godot4 >/dev/null 2>&1; then
    godot=godot4
elif command -v godot >/dev/null 2>&1; then
    godot=godot
else
    printf '%s\n' 'Godot 4.7.x no esta instalado o no se encuentra en PATH.' >&2
    printf '%s\n' 'Instalalo y abre este proyecto con: godot4 --path "<carpeta del proyecto>"' >&2
    exit 1
fi

exec "$godot" --path "$project_dir"
