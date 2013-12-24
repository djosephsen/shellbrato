#!/bin/sh

source ./shellbrato.sh
debug "shellbrato successfully sourced"
debug "curl is ${C}"
debug  "jq is ${JQ}"
debug  "queue file is ${QFILE}"

#get some metrics
read five ten fifteen <<< $(uptime | cut -d\  -f15,16,17)

sendCounter "$(date +%s)||test_load5||${five}||homebase"
sendGauge "$(date +%s)||test_load10||${ten}||homebase"

queueCounter "$(date +%s)||test_load5||${five}||homebase"
queueGauge "$(date +%s)||test_load15||${fifteen}||homebase"
queueGauge "$(date +%s)||test_load10||${ten}||homebase"
sendMetrics
