#!/bin/sh

source ./shellbrato.sh
NOW=$(date +%s)
debug "shellbrato successfully sourced"
debug "curl is ${C}"
debug  "jq is ${JQ}"
debug  "queue file is ${QFILE}"

#get some metrics
read five ten fifteen <<< $(uptime | sed -e 's/.*average[^:]*: //'| tr -d ',')

#queue them up to send
queueCounter "${NOW}||test_counter||${NOW}||homebase"
queueGauge "${NOW}||test_load5||${five}||homebase"
queueGauge "${NOW}||test_load10||${ten}||homebase"
queueGauge "${NOW}||test_load15||${fifteen}||homebase"

#send them
sendMetrics

getMetric test_load5 $(date -d yesterday +%s)
