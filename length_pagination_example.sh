#!/bin/sh
#This sample search script uses the "length" hint returned by 
#the librato API in a while loop to page through search results

source ${SBHOME}/shellbrato.sh

#DEBUG=1 #(uncomment to see debug info from shellbrato)
OFFSET=0

#make an initial query to populate the length and offset variables
R=$(listMetrics)
LENGTH=$(echo ${R} | ${JQ} .query | grep length | tr -d '\n {},' | cut -d: -f2)
OFFSET=$((${OFFSET}+${LENGTH}))

#continue to loop as long as the API returns 100 for length
while [ "${LENGTH}" -eq 100 ]
do
	RE="${RE}${R}"	
	R=$(listMetrics ${OFFSET})
	LENGTH=$(echo ${R} | ${JQ} .query | grep length | tr -d '\n {},' | cut -d: -f2)
	OFFSET=$((${OFFSET}+${LENGTH}))
done


#echo ${RE} | ${JQ} . 
echo "pages: $(((${OFFSET}/100)+1))"
echo "Total metrics: ${OFFSET}"
