#!/usr/bin/env sh
# Portable editor launcher for Linux and macOS.
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v godot4 >/dev/null 2>&1; then
    godot=godot4
elif command -v godot >/dev/null 2>&1; then
    godot=godot
else
    printf '%s\n' 'Godot 4.7.x no esta instalado o no se encuentra en PATH.' >&2
    exit 1
fi

exec "$godot" --editor --path "$project_dir" res://rooms/room_01.tscn
