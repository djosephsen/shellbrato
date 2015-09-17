#!/bin/sh
# A proper shell library for Librato 
#blame dave Mon Dec 23 12:33:15 CST 2013

##### globals ###########
SBVER='0.1' #shellbrato version
QFILE=/tmp/LBTemp_$(date +%s)
CinQ=0
GinQ=0
API_RETURN_MAX=100
METRICS_URL="https://metrics-api.librato.com"
METRICS_API_URL="${METRICS_URL}/v1/metrics"
ALERTING_API_URL="${METRICS_URL}/v1/alerts"
ANNOTATIONS_API_URL="${METRICS_URL}/v1/annotations"
C_OPTS="--silent --connect-timeout 5 -m90 -A shellbrato/${SBVER}::${SHELL}"

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

function print {
	[ "${GET_FILTER}" ] || GET_FILTER=$(which cat)

   if [ -z "${PAGINATE}" ] # don't use GET_FILTER inside pagination loops
	then
		echo "$@" | ${GET_FILTER}
	else
		echo "$@"
	fi
}

function checkSanity {
# Make sure we have what we need
debug "checkSanity: enter"

	[ "${GET_FILTER}" ] || GET_FILTER=$(which cat)
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

function doPOST {
# generic HTTP POST function
#$1 is the path 
#$3 is post data
debug "doPOST: enter"
debug "doPOST: exit"
}

function doGET {
# generic HTTP GET function
#$1 is the path 
debug "doGET: enter"
debug "doGET: exit"
}

function sendMetrics {
# take everything out of the queue file (named by $1) and send it
debug "SendMetrics: enter"

	MYQ="${1}"
	[ "${MYQ}" ] || error "sendMetrics() requires a Queue name argument (one is returned when you call the queue functions)"
	[ "${MTIME}" ] || MTIME="measure_time=$(date +%s)"
	[ "${DEFAULT_SOURCE}" ] || DEFAULT_SOURCE="$(hostname)"

	POST_PREFIX="-d measure_time=${MTIME}&source=${DEFAULT_SOURCE}"
	POST_SUFFIX=$(cat "${MYQ}" | tr -d '\n')
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
	Q=$(enQueue "counters" "${METRIC}")
	sendMetrics ${Q}

debug "sendCounter: exit"
}

function sendGauge {
#immediatly send a single gauge measurement
debug "sendGauge: enter"

	METRIC=$(echo ${1} | tr  ' ' '_')
	Q=$(enQueue "gauges" "${METRIC}")
	sendMetrics ${Q}

debug "sendGauge: exit"
}

function queueCounter {
# append a counter measurement to the queue to send later
debug "queueCounter: enter"
	METRIC=$(echo ${1} | tr  ' ' '_')
	Q=$(enQueue "counters" "${METRIC}")
	echo "${Q}"
debug "queueCounter: exit"
}

function queueGauge {
# append a gauge measurement to the queue to send later
debug "queueGauge: enter"
	METRIC=$(echo ${1} | tr  ' ' '_')
	Q=$(enQueue "gauges" "${METRIC}")
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

	#start building the query
	QUERY="-d resolution=${GET_RESOLUTION} -d start_time=${2}"
	[ "${GET_SUMMARIZE}" ] && QUERY="${QUERY} -d summarize_sources=true"
	[ "${GET_SOURCE}" ] && QUERY="${QUERY} -d source=${GET_SOURCE}"
	[ "${GET_SOURCES}" ] && QUERY="${QUERY} -d sources[]=${GET_SOURCES}"

	if [ "${3}" ]
	then
		QUERY="${QUERY} -d end_time=${3}" 
	else
		QUERY="${QUERY} -d end_time=$(date +%s)"
	fi

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${QUERY} -X GET ${METRICS_API_URL}/${1}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${QUERY} -X GET ${METRICS_API_URL}/${1})

	print "${OUT}"

debug "getMetric: exit"
}

function listMetrics {
# returns a list of metrics from the librato api
# usage: listMetrics offset
debug "listMetrics: enter"

	if [ "${1}" ]; then LMOFFSET=${1}; else LMOFFSET=0; fi

	#Set-able options

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${METRICS_API_URL}?offset=${LMOFFSET}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${METRICS_API_URL}?offset=${LMOFFSET})

	print "${OUT}"

debug "listMetrics: exit"
}

function listAlerts {
# returns a list of alerts from the librato api
# usage: listAlerts offset
debug "listAlerts: enter"

	if [ "${1}" ]; then LAOFFSET=${1}; else LAOFFSET=0; fi


	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${VER} -X GET ${ALERTING_API_URL}?offset=${LAOFFSET}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${VER} -X GET ${ALERTING_API_URL}?offset=${LAOFFSET})

	print out

debug "listAlerts: exit"
}

function getAlertByID {
# function to fetch an alert from the api using it's ID number
# usage: getAlert IDNUM
debug "getAlert: enter"

	#Set-able options
	[ "${1}" ] || error "getAlert: arg1 should be alert ID"

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${ALERTING_API_URL}/${1}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${ALERTING_API_URL}/${1})

	print "${OUT}"

debug "getAlert: exit"
}

function listAnnotationStreams {
# function to list all annotation streams
# usage: listAnnotations
debug "listAnnotations: enter"

	if [ "${1}" ]; then LAOFFSET=${1}; else LAOFFSET=0; fi
	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${ANNOTATIONS_API_URL}?offset=${LAOFFSET}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -X GET ${ANNOTATIONS_API_URL}?offset=${LAOFFSET})

	print "${OUT}"

debug "listAnnotations: exit"
}

function getAnnotation {
# function to fetch all the events from a named annotation stream from the api
# usage: getAnnotation <name> <startepoc> <endepoc>
debug "getAnnotation: enter"

	gaNAME=${1}
	[ "${gaNAME}" ] || error "getAnnotation usage: getAnnotation <name> [start-epoc]"
	gaOFFSET=${2}
	[ "${gaOFFSET}" ] || gaOFFSET=0

   #start building the query
   QUERY="-d start_time=${gaOFFSET}"
   [ "${GET_SOURCES}" ] && QUERY="${QUERY} -d sources[]=${GET_SOURCES}"

   if [ "${3}" ]
   then
      QUERY="${QUERY} -d end_time=${3}"
   else
      QUERY="${QUERY} -d end_time=$(date +%s)"
   fi
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${QUERY} -X GET ${ANNOTATIONS_API_URL}/${gaNAME}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} ${QUERY} -X GET ${ANNOTATIONS_API_URL}/${gaNAME})

	print "${OUT}"
}

function sendAnnotation {
debug "sendAnnotation: enter"
# sendAnnotation '<stream>||<title>||[start]||[end]'
# you may also export $SOURCE and $DESCRIPTION

	[ "${SOURCE}" ] || SOURCE="$(hostname)"
	saSTREAM=$(echo ${1} | awk -F '[|][|]' '{print $1}')
	saTITLE=$(echo ${1} | awk -F '[|][|]' '{print $2}')
	saSTART=$(echo ${1} | awk -F '[|][|]' '{print $3}')
	[ "${saSTART}" ] || saSTART="$(date +%s)"
	saEND=$(echo ${1} | awk -F '[|][|]' '{print $4}')

	POST_DATA="title=${saTITLE}&source=${SOURCE}"
	[ "${DESCRIPTION}" ] && POST_DATA="${POST_DATA}&description=${DESCRIPTION}"
	POST_DATA="${POST_DATA}&start_time=${saSTART}"
	[ "${saEND}" ] && POST_DATA="${POST_DATA}&end_time=${saEND}"

	#lets kick this pig
	debug "${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -d ${POST_DATA} -X POST ${ANNOTATIONS_API_URL}/${saSTREAM}"
	OUT=$(${C} ${C_OPTS} -u ${LBUSER}:${LBTOKEN} -d "${POST_DATA}" -X POST ${ANNOTATIONS_API_URL}/${saSTREAM})

	print "${OUT}"
	unset saSTREAM saTITLE saSTART saEND POST_DATA DESCRIPTION OUT
}

function paginate {
# Wrapper function to return paginated results for a given query
# usage: paginate <other-shellbrato-function> [options]
#######  this is experimental and probably fragile #########
debug 'paginate enter'
	PQUERY="${@}" # the query as we recieved it (pagination query)
	debug "pquery: ${PQUERY}"

	#get commands use 'next_time-style' pagination
	if echo ${PQUERY}| grep -q '^get'
	then
		# this generally works for all of the 'get' commands, where the syntax is
		# getThing nameOfThing offset
		PTYPE='next_time'
		PQ=$(echo ${PQUERY} | cut -d\  -f1)
		QID=$(echo ${PQUERY} | cut -d\  -f2)
		PAGINATE=$(echo ${PQUERY} | sed -e "s/^getMetric ${QID}//")
	else
		# this generally works for all of the 'list' commands, where the syntax is
		# listThings offset
		PTYPE='length'
		PQ=$(echo ${PQUERY} | cut -d\  -f1)
		PAGINATE=$(echo ${PQUERY} | sed -e "s/^${PQ}//")
	fi

	# run the initial query
	debug "running:: ${PQ} ${QID} ${PAGINATE}"
	R="$(${PQ} ${QID} ${PAGINATE})"
	RE=$(echo ${R}| ${JQ} .)
	PAGINATE=$(echo ${R} | ${JQ} ".query.${PTYPE}")
	OFFSET=${PAGINATE}

	#see if follow-up queries are necessary
	while checkPaginate "${PTYPE}" "${PAGINATE}" 
	do
		debug "running:: ${PQ} ${QID} ${OFFSET}"
		R="$(${PQ} ${QID} ${OFFSET})"
	   RE="${RE}$(echo ${R}| ${JQ} .)" #store the combined query results 
	   PAGINATE=$(echo ${R} | ${JQ} ".query.${PTYPE}")
		if [ "${PAGINATE}" != 'null' ]
		then
			OFFSET=$(computeOffset ${PTYPE} ${PAGINATE} ${OFFSET})
		else
			OFFSET='null'
		fi
	done

	unset PAGINATE
	print ${RE}
	unset PQ PTYPE QID R RE OFFSET
}

function checkPaginate {
#return true if the value of $1 indicates we should keep paginating
debug 'checkPaginate enter'
	cpTYPE=${1}
	[ "${cpTYPE}" ] || error "checkPaginate usage: checkPaginate <value> <type>"
	cpVAL=${2}
	[ "${cpVAL}" ] || return 1 #assume no pagination hint returned from api
		

	if [ "${cpTYPE}" == "length" ]
	then
		if [ "${cpVAL}" -eq ${API_RETURN_MAX} ]
		then
			return 0
		fi
	elif [ "${cpTYPE}" == "next_time" ]
	then
		if [ "${cpVAL}" != 'null' ]
		then
			return 0
		fi
	else
		error "checkPaginate: unknown type: ${cpTYPE}"
	fi

	debug 'checkPaginate exit'
	return 1
}

function computeOffset {
# computes the proper value of the pagination variable depending on
# the type of pagination desired

	spTYPE=${1}
	spNEXT=${2}
	spCURRENT=${3}

	if [ "${spTYPE}" == "length" ]
	then
		echo $((${spNEXT}+${spCURRENT}))
		return 0
	elif [ "${spTYPE}" == "next_time" ]
	then
		echo ${spNEXT}
		return 0
	else
		error "setPaginate: unknown type: ${cpTYPE}"
	fi
}

checkSanity
