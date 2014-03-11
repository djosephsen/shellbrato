#r!/bin/sh
# A proper shell library for Librato 
#blame dave Mon Dec 23 12:33:15 CST 2013

##### globals ###########
SBVER='0.1' #shellbrato version
QFILE=/tmp/LBTemp_$(date +%s)
CinQ=0
GinQ=0
METRICS_URL="https://metrics-api.librato.com"
METRICS_API_URL="${METRICS_URL}/v1/metrics"
ALERTING_API_URL="${METRICS_URL}/v1/alerts"
C_OPTS="--silent -A shellbrato/${SBVER}::$(/bin/sh --version | head -n1 | tr ' ' '_')"

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
		if ! [ "${SBHOME}" ] 
		then
			if [ -e '/opt/shellbrato/shellbrato.sh' ]
			then
				SBHOME='/opt/shellbrato'
			elif [ -e './shellbrato.sh' ]
			then
				SBHOME='./'
			else
				error 'Please export SBHOME=<where you installed shellbrato>'
			fi
		fi
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

function DoPOST {
# generic HTTP POST function
#$1 is the path 
#$3 is post data
debug "DoPOST: enter"
debug "DoPOST: exit"
}

function sendMetrics {
# take everything out of the queue file (named by $1) and send it
debug "SendMetrics: enter"

	MYQ="${1}"
	[ "${MTIME}" ] || MTIME="measure_time=$(date +%s)"
	[ "${DEFAULT_SOURCE}" ] || DEFAULT_SOURCE="$(hostname)"

	POST_PREFIX="-d measure_time=${MTIME}&source=${DEFAULT_SOURCE}"
	POST_SUFFIX=$(cat ${MYQ} | tr -d '\n')
	POST_DATA="${POST_PREFIX}${POST_SUFFIX}"

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${POST_DATA} -X POST ${METRICS_API_URL}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} "${POST_DATA}" -X POST ${METRICS_API_URL})

	if [ "${OUT}" ]
	then
		error "TRANSMISSION ERROR:: $(echo ${OUT} | ${JQ} .)"
	else
		debug "SendMetrics:: Success!"
	fi

 #dont leak tempfiles
 rm -Rf ${MYQ}
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

	QFILE="/tmp/$$.tmp" 
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

	echo "${QFILE}" #return the name of the queue

debug "enQueue: exit"
}


function sendCounter {
#immediatly send a single counter measurement
debug "sendCounter: enter"

	METRIC=$(echo ${1} | tr ' ' '_')
	Q=enQueue "counters" "${METRIC}"
	sendMetrics ${Q}

debug "sendCounter: exit"
}

function sendGauge {
#immediatly send a single gauge measurement
debug "sendGauge: enter"

	METRIC=$(echo ${1} | tr  ' ' '_')
	Q=enQueue "gauges" "${METRIC}"
	sendMetrics ${Q}

debug "sendGauge: exit"
}

function queueCounter {
# append a counter measurement to the queue to send later
debug "queueCounter: enter"
	METRIC=$(echo ${1} | tr  ' ' '_')
	Q=enQueue "counters" "${METRIC}"
	echo "${Q}"
debug "queueCounter: exit"
}

function queueGauge {
# append a gauge measurement to the queue to send later
debug "queueGauge: enter"
	METRIC=$(echo ${1} | tr  ' ' '_')
	Q=enQueue "gauges" "${METRIC}"
	echo "${Q}"
debug "queueGauge: exit"
}

function getMetric {
# function to get metric data from the API
# usage: getMetric metric_name epoc_start_time epoc_end_time
debug "getMetric: enter"

	#Set-able options
	[ "${GET_RESOLUTION}" ] || GET_RESOLUTION='1'
	[ "${1}" ] || error "getMetric: arg1 should be metric name"
	[ "${2}" ] || error "getMetric: arg2 should be start time in epoc secs"
	[ "${GET_FILTER}" ] || GET_FILTER=$(which cat)

	#start building the query
	QUERY="-d resolution=${GET_RESOLUTION} -d start_time=${2}"
	[ "${GET_SUMMARIZE}" ] && QUERY="${QUERY} -d summarize_sources=true"
	[ "${GET_SOURCE}" ] && QUERY="${QUERY} -d ${GET_SOURCE}"

	if [ "${3}" ]
	then
		QUERY="${QUERY} -d end_time=${3}" 
	else
		QUERY="${QUERY} -d end_time=$(date +%s)"
	fi

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${QUERY} -X GET ${METRICS_API_URL}/${1}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${QUERY} -X GET ${METRICS_API_URL}/${1})

	echo ${OUT}|${GET_FILTER}


debug "getMetric: exit"
}

function listMetrics {
# returns a list of metrics from the librato api
# usage: listMetrics offset
debug "listMetrics: enter"

	if [ "${1}" ]; then LMOFFSET=${1}; else LMOFFSET=0; fi

	#Set-able options
	[ "${LIST_FILTER}" ] || GET_FILTER=$(which cat)

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${METRICS_API_URL}?offset=${LMOFFSET}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${METRICS_API_URL}?offset=${LMOFFSET})

	echo ${OUT}|${GET_FILTER}

debug "listMetrics: exit"
}

function listAlerts {
# returns a list of alerts from the librato api
# usage: listAlerts offset
debug "listAlerts: enter"

	if [ "${1}" ]; then LAOFFSET=${1}; else LAOFFSET=0; fi

	#Set-able options
	[ "${LIST_FILTER}" ] || GET_FILTER=$(which cat)

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${VER} -X GET ${ALERTING_API_URL}?offset=${LAOFFSET}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${VER} -X GET ${ALERTING_API_URL}?offset=${LAOFFSET})

	echo ${OUT}|${GET_FILTER}

debug "listAlerts: exit"
}

function getAlertByID {
# function to fetch an alert from the api using it's ID number
# usage: getAlert IDNUM
debug "getAlert: enter"

	#Set-able options
	[ "${1}" ] || error "getAlert: arg1 should be alert ID"
	[ "${GET_FILTER}" ] || GET_FILTER=$(which cat)

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${ALERTING_API_URL}/${1}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${ALERTING_API_URL}/${1})

	echo ${OUT}|${GET_FILTER}


debug "getAlert: exit"
}

checkSanity
