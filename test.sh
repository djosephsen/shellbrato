#!/bin/sh

source ./shellbrato.sh
debug "shellbrato successfully sourced"
debug "curl is ${C}"
debug  "jq is ${JQ}"

read five ten fifteen <<< $(uptime | cut -d\  -f15,16,17)

queueCounter "$(date +%s)||load5||${five}||homebase"
queueGauge "$(date +%s)||load10||${ten}||homebase"
