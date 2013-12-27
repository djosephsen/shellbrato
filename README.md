shellbrato
==========

## Want to push metrics to Librato from your shell scripts? 

Shellbrato is a shell library client for working with Librato. It works on
Linux and Darwin systems that have: 

* The usual shell tools (echo, cat, tail, tr, cut)
* sed and awk
* [curl](curl.haxx.se/)
* [jq](http://stedolan.github.io/jq/)

Shellbrato uses jq to parse json from the API, and comes with 32 and 64 bit
binary versions of jq for OSX and Linux. Shellbrato will attempt to detect and
use the appropriate built-in jq if one isn't found on your system. 

## Installing
Installing shellbrato is pretty easy. 

	git clone https://github.com/djosephsen/shellbrato.git
	sudo cp -a shellbrato /opt #(or wherever)
	export SBHOME=/opt/shellbrato #(or wherever)
	export LBUSER=<your librato username>
	export LBTOKEN=<your librato token>

you can now add the following line near the top of your shell scripts: 
	source /opt/shellbrato/shellbrato.sh

## Sending metrics

You can send metrics immediately with the functions: "sendCounter", and
"sendGauge", or you can queue up a bunch of metrics and send them all at once
with "queueCounter", and "queueGauge", followed by "sendMetrics". For example: 

	#store the current time
	now=$(date +%s)

	#get three gauge metrics
	read five ten fifteen <<< $(uptime | sed -e 's/.*average[^:]*: //'| tr -d ',')

	#send the first one immediately
	sendGauge "${now}||test_load5||${five}||homebase"

	#queue up the other two
	queueGauge "${now}||test_load10||${ten}||homebase"
	queueGauge "${now}||test_load15||${fifteen}||homebase"

	#get a counter metric
	counter=$(date +%s)

	#add the counter metric to the queue
	queueCounter "${now}||test_counter||${counter}||homebase"

	#now send everything in the queue
	sendMetrics

The argument to all four of these functions is the same, a single string,
composed of four fields separated by double pipe characters (||). The fields
are: 

1. The day/time stamp in epoch seconds format.
2. The name of the metric as it will appear in the librato system. 
3. The numerical value of the measurement itself. 
4. An optional source name (if you don't specify a source, shellbrato will use $(hostname)


## Fetching metrics

The Current metric-fetching capabilities of shellbrato are pretty nascent. The
getMetric function takes three arguments: 

1. The metric name
2. The start time in epoch seconds
3. Optionally, the end time in epoch seconds (if you don't specify an end time, shellbrato will use now)

For example:

	#grab all values of test_load5 since yesterday
	getMetric test_load5 $(date -d yesterday +%s)

You can influence the behavior of the search by setting the following
variables: 

* GET_RESOLUTION- sets the API [&resolution](http://dev.librato.com/v1/get/metrics/:name) option
* GET_SUMMARIZE- sets the API [&summarize_sources](http://dev.librato.com/v1/get/metrics/:name) option
* GET_SOURCE- sets the API [&source](http://dev.librato.com/v1/get/metrics/:name) option


The getMetric function returns an unformatted blob of json. You may use jq in
your script to parse the blob however you want. Shellbrato doesn't handle
[pagination](http://dev.librato.com/v1/pagination) for you, so your query
results may be truncated depending on the number of measurements that are
returned. A sample query script is provided that shows how to properly use
[pagination](http://dev.librato.com/v1/pagination) hints from the API to make
follow-up queries. 

I might add some convenience functions some time later so you don't have to
learn jq (but it's basically awesome so you totally should). 

## Design Considerations and Gotchas
I've attempted to keep this library agnostic to the type of shell you're using
(I wrote this using bash, so that's probably your best bet), and also agnostic
to the unix you're using (I've only tested with Linux and Darwin). This meant
avoiding things like in-memory data structures for the send queue, and other
elegant nice-to-haves. So if you're looking at the source and are wondering wtf
I was thinking, compatibility probably has something to do with it. 

You should also be aware that, for now, internally, when you call an immediate
send function like "sendGauge" your metric is added to the queue file, and then
the queue file is immediately flushed with sendMetrics. 

This means that any other metrics that you've previously queued, will be sent
along with any invocation of "sendGauge", or "sendCounter". This was a trade
off decision I made to maintain Darwin compatibility. Darwin doesn't seem to
have a 'tempfile' binary by default, so I need to research and decide on the
cleanest way to generate random temp files on Darwin (probably $RANDOM). In the
near future, I'll separate the queues.

Finally, I used double-pipe delimiters because many metric names are themselves
deliminted with all sorts of interesting and creative characters. Very few
people use multiple-character delimiters though (and they're all masochists so
they wouldn't use this library anyway), so although double pipes introduce an
awk dependency, they make things generally a lot safer. Sorry about that. 
