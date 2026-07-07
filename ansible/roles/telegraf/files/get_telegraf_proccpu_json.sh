#!/bin/bash

# shellcheck source=ansible/roles/telegraf/files/get_telegraf_json_common.sh
source "$(dirname "$(readlink -f "$0")")/get_telegraf_json_common.sh"

SAMPLING_SEC=5

telegraf_json_open
pidstat -u -h -l "${SAMPLING_SEC}" 1 |
    tail -n +4 |
    awk '{ cpu=$8; $1=$2=$3=$4=$5=$6=$7=$8=$9=""; print cpu,$0 }' |
    sort -n |
    while read -r cpu cmd; do
        if [[ ${cpu%%.*} -le 0 ]]; then
            continue
        fi
        telegraf_json_entry "$cmd" "$cpu"
    done
telegraf_json_close
