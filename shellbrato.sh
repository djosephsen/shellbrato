#!/bin/sh
# A proper shell library for Librato 
#blame dave Mon Dec 23 12:33:15 CST 2013

##### globals ###########
QFILE=/tmp/LBTemp_$(date +%s)
CinQ=0
GinQ=0
METRICS_URL="https://metrics.librato.com/"
METRICS_API_URL="${METRICS_URL}/metrics-api/v1/metrics"


##### functions #########
function error {
# Print an error and exit
	echo "$@" >&2
	exit 42
}

function warn {
# Print a warning and keep on chuggin
	echo "$@" >&2
}

function debug {
# Print a debugging hint if DEBUG is set
	[ "${DEBUG}" ] && echo "$@" >&2
}

function checkSanity {
# Make sure we have what we need
debug "checkSanity: enter"

	[ "${LBUSER}" ] || error 'Please export LBUSER=<your librato username>'
	[ "${LBTOKEN}" ] || error 'Please export LBTOKEN=<your librato token>'
	C="$(which curl 2>/dev/null)" || 'Please install Curl'
	[ "${JQ}" ] || JQ=$(which jq 2>/dev/null)

	if ! [ "${JQ}" ] #crud, lets see if they can use one of our jq binaries
	then
		[ "${SBHOME}" ] || error 'Please export SBHOME=<where you installed shellbrato>'
		if [ "$(uname)" == 'Linux' ]
		then
			if [ "$(uname -i)" == 'i386' ]
			then
				${JQ}=${SBHOME}/bin/linux32/jq
			elif uname -i | grep -q '64'
			then
				${JQ}=${SBHOME}/bin/linux64/jq
			else
				warn "Sorry, we couldnt detect your system architecture: $(uname -i)" 
			fi
		elif [ "$(uname)" == 'Darwin' ]
		then
			if [ "$(uname -m)" == 'x86_64' ]
			then
				${JQ}=${SBHOME}/bin/osx64/jq
			else
				${JQ}=${SBHOME}/bin/osx32/jq
			fi
		else
			warn 'Sorry, we couldnt detect your system architecture'
		fi
	fi
	#epic fail
	[ "${JQ}" ] || error 'Please export JQ=<where jq is installed> (or link it somewhere in your PATH, and we will detect it next time'
			
	rm -Rf /tmp/LBTemp_* #don't leak tempfiles
	debug "checkSanity: sane"

debug "checkSanity: exit"
}

function sendMetrics {
# take everything out of the queue file and send it
debug "SendMetrics: enter"


	[ "${MTIME}" ] || MTIME="measure_time=$(date +%s)"
	[ "${DEFAULT_SOURCE}" ] || DEFAULT_SOURCE="$(hostname)"

	POST_DATA="-d measure_time=${MTIME}&source=${DEFAULT_SOURCE}"
	POST_DATA="${POST_DATA}$(cat ${QFILE})"

	debug "${C} -u ${LBUSER}:${LBTOKEN} ${POST_DATA} -X POST https://metrics-api.librato.com/v1/metrics"
	#${C} -u ${LBUSER}:${LBTOKEN} ${POST_DATA} -X POST https://metrics-api.librato.com/v1/metrics

 #reset the queue
 rm -Rf ${QFILE}
 CinQ=0
 GinQ=0

debug "sendMetrics: exit"
}

function enQueue {
#translate the input to POST data, and save it in the queue file
# Input: $1: "type" $2: "epoctime||metric_name||value||optional_source"
debug "enQueue: enter"
	
		#read VTIME MNAME MVALUE SOURCE <<< $(awk -F '[|][|]' '{print $1" "$2" "$3" "$4}' <<< ${2})
	#cleaner and less awk, but not sure if '<<<' is compatible with non-bash shells

	if [ "${1}" == 'counters' ] 
	then
		N=${CinQ}
		CinQ=$((${CinQ}+1))
	else
		N=${GinQ}
		GinQ=$((${GinQ}+1))
	fi

	VTIME=$(echo ${2} | awk -F '[|][|]' '{print $1}')
	MNAME=$(echo ${2} | awk -F '[|][|]' '{print $2}')
	MVALUE=$(echo ${2} | awk -F '[|][|]' '{print $3}')
	SOURCE=$(echo ${2} | awk -F '[|][|]' '{print $4}')


	echo "&${1}[${N}][name]=${MNAME}" >> ${QFILE}
	echo "&${1}[${N}][value]=${MVALUE}" >> ${QFILE}
	echo "&${1}[${N}][measure_time]=${VTIME}" >> ${QFILE}
	[ "${SOURCE}" ] && echo "&${1}[${N}][source]=${SOURCE}" >> ${QFILE}
	
	unset VTIME MNAME MVALUE SOURCE N

debug "enQueue: exit"

}


function sendCounter {
#immediatly send a single counter measurement
debug "sendCounter: enter"

	METRIC=$(echo ${1} | tr ' ' '_')
	enQueue "counters" "${METRIC}"
	sendMetrics

debug "sendCounter: exit"
}

function sendGauge {
#immediatly send a single gauge measurement
debug "sendGauge: enter"

	METRIC=$(echo ${1} | tr  ' ' '_')
	enQueue "gauges" "${METRIC}"
	sendMetrics

debug "sendGauge: exit"
}

function queueCounter {
# append a counter measurement to the queue to send later
debug "queueCounter: enter"
	METRIC=$(echo ${1} | tr  ' ' '_')
	enQueue "counters" "${METRIC}"
debug "queueCounter: exit"
}

function queueGauge {
# append a gauge measurement to the queue to send later
debug "queueGauge: enter"
	METRIC=$(echo ${1} | tr  ' ' '_')
	enQueue "gauges" "${METRIC}"
debug "queueGauge: exit"
}


function getMetric {
debug "getMetric: enter"

#  CURL_OUTPUT=`curl \
#    --silent \
#    -u ${LBUSER}:${LBTOKEN} \
#    -d "resolution=1" \
#    -d "start_time=$START" \
#    -d "end_time=$END" \
#    -d "sources=${DEFAULT_SOURCE}" \
#    ${SUMMARIZE_OPTIONS} \
#    -X GET ${METRICS_API_URL}/${METRIC_NAME}`

debug "getMetric: exit"
}

checkSanity
