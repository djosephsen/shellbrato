#!/bin/sh
#This sample search script uses the "next_page" hint returned by 
#the librato API in a while loop to page through search results

source ${SBHOME}/shellbrato.sh

#DEBUG=1 #(uncomment to see debug info from shellbrato)

METRIC_NAME='collectd.load.load.shortterm' #the name of the metric we want
NEXT_TIME=$(date -d "yesterday" +%s) #the initial start time in epoc seconds
P=0 #page counter

while [ "${NEXT_TIME}" != 'null' ] 
do
	#make the query using getMetric
	R="$(getMetric ${METRIC_NAME} ${NEXT_TIME})"
	#store the combined query results in RE
	RE="${RE}${R}" 
	#check for a next_time hint from the API in the last result set
	NEXT_TIME=$(echo ${R} | ${JQ} '.query' | tr -d '\n {},' | cut -d: -f2)
	#count the pages
	P=$((${P}+1))
done

echo ${RE} | ${JQ} . 
echo 
echo "Pages: $P"
echo "Datapoints: $(echo ${RE} | ${JQ} . | grep 'value' | wc -l)"

