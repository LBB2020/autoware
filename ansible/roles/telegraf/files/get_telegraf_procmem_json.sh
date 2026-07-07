#!/bin/bash

# shellcheck source=ansible/roles/telegraf/files/get_telegraf_json_common.sh
source "$(dirname "$(readlink -f "$0")")/get_telegraf_json_common.sh"

telegraf_json_open
ps -ax --format "rss command" |
    while read -r rss cmd; do
        if [[ $rss -lt 30000 ]]; then
            continue
        fi
        telegraf_json_entry "$cmd" "$rss"
    done
telegraf_json_close
