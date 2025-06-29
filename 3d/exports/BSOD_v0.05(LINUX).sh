#!/bin/sh
echo -ne '\033c\033]0;BSOD\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/BSOD_v0.05(LINUX).x86_64" "$@"
