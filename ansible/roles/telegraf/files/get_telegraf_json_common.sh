#!/bin/bash

# Shared helpers for the get_telegraf_*_json.sh process-metric scripts.
# These scripts emit a JSON object mapping a sanitized process command to a
# numeric metric value, terminated with a fixed "z":0 entry so the object is
# always valid even when no process matches.

# Sanitize a process command for use as a JSON key: replace spaces and '='
# with underscores and truncate to 50 characters.
telegraf_sanitize_cmd() {
    local cmd="$1"
    cmd="${cmd// /_}"
    cmd="${cmd//=/_}"
    printf '%s' "${cmd:0:50}"
}

telegraf_json_open() {
    echo "{"
}

# Emit a single "key":value, JSON entry with the command sanitized as the key.
telegraf_json_entry() {
    local cmd="$1"
    local value="$2"
    echo "\"$(telegraf_sanitize_cmd "$cmd")\":${value},"
}

telegraf_json_close() {
    echo '"z":0'
    echo "}"
}
