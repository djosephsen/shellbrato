#!/bin/sh
# A proper shell library for Librato 
#blame dave Mon Dec 23 12:33:15 CST 2013

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

function checkSanity {
# Make sure we have what we need

	[ "${LBUSER}" ] || error 'Please export LBUSER=<your librato username>'
	[ "${LBTOKEN}" ] || error 'Please export LBTOKEN=<your librato token>'
	C="$(which curl)" || 'Please install Curl'
	[ "${JQ}" ] || JQ=$(which jq)

	if ! [ "${JQ}" ] #crud, lets see if they can use one of our jq binaries
	then
		[ "${SBHOME}" ] || error 'Please export SBHOME=<where you installed shellbrato>'
		if [ "$(uname)" -eq 'Linux' ]
		then
			if [ "$(uname -i)" -eq 'i386' ]
			then
				${JQ}=${SBHOME}/bin/linux32/jq
			elif $(uname -i) | grep -q '64'
			then
				${JQ}=${SBHOME}/bin/linux64/jq
			else
				warn 'Sorry, we couldnt detect your system architecture'
			fi
		elif [ "$(uname)" -eq 'Darwin' ]
		then
			if [ "$(uname -m)" -eq 'x86_64' ]
			then
				${JQ}=${SBHOME}/bin/osx64/jq
			else
				${JQ}=${SBHOME}/bin/osx32/jq
			fi
		else
			warn 'Sorry, we couldnt detect your system architecture'
		fi
			
	#epic fail
	[ "${JQ}" ] || error 'Please export JQ=<where jq is installed> (or link it somewhere in your PATH, and we will detect it next time'
			
	
