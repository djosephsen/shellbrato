#!/bin/sh

source ./shellbrato.sh
NOW=$(date +%s)
debug "shellbrato successfully sourced"
debug "curl is ${C}"
debug  "jq is ${JQ}"
debug  "queue file is ${QFILE}"

#generate some metrics
read five ten fifteen <<< $(uptime | sed -e 's/.*average[^:]*: //'| tr -d ',')

#queue them up to send
Q=$(queueCounter "${NOW}||test_counter||${NOW}||homebase")
Q=$(queueGauge "${NOW}||test_load5||${five}||homebase")
Q=$(queueGauge "${NOW}||test_load10||${ten}||homebase")
Q=$(queueGauge "${NOW}||test_load15||${fifteen}||homebase")

#send them
sendMetrics ${Q}

#read some metrics back from the api
getMetric test_load5 $(date -d yesterday +%s)

#list some alerts from the api

listAlerts
