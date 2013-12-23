#!/bin/sh
# A proper shell library for Librato 
#blame dave Mon Dec 23 12:33:15 CST 2013

##### globals ###########
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
	C="$(which curl) 2>/dev/null" || 'Please install Curl'
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
			
debug "checkSanity: sane"
debug "checkSanity: exit"
}

function putMetric {
debug "putMetric: enter"

[ "${MTIME}" ] || MTIME="measure_time=$(date +%s)"

${C}
 -u ${LBUSER}:${LBTOKEN}
 -d 'measure_time=${MTIME}&source=blah.com' \
 '&counters[0][name]=conn_servers' \
 '&counters[0][value]=5' \
 '&counters[1][name]=write_fails' \
 '&counters[1][value]=3' \
 '&gauges[0][name]=cpu_temp' \
 '&gauges[0][value]=88.4' \
 '&gauges[0][source]=cpu0_blah.com' \
 '&gauges[0][measure_time]=1234567949'
 -X POST https://metrics-api.librato.com/v1/metrics

debug "putMetric: exit"
}

function putCounter {
debug "putCounter: enter"
debug "putCounter: exit"
}

function putGague {
debug "putGague: enter"
debug "putGague: exit"
}


function getMetric {
debug "getMetric: enter"

#  CURL_OUTPUT=`curl \
#    --silent \
#    -u ${LBUSER}:${LBTOKEN} \
#    -d "resolution=1" \
#    -d "start_time=$START" \
#    -d "end_time=$END" \
#    -d "sources=${LBSOURCE}" \
#    ${SUMMARIZE_OPTIONS} \
#    -X GET ${METRICS_API_URL}/${METRIC_NAME}`

debug "getMetric: exit"
}

checkSanity
