shellbrato
==========

## Want to push metrics to Librato from your shell scripts? 

Shellbrato is a shell library client for working with Librato. It works on
Linux and Darwin systems that have: 

* The usual shell tools (echo, cat, tail, tr, cut)
* sed and awk
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
	queueCounter "${now}||test_counter||||homebase"

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
3. Optionally, the end time in epoch seconds

For example:

	#grab all values of test_load5 since yesterday
	getMetric test_load5 $(date -d yesterday +%s)

The getMetric function will correctly page through all the historical values
for you, but once it has them it basically just dumps them out using jq with a
filter of ".". 

Once I've played around with the data I'll probably have a better handle on how
getMetric should actually behave. I have a feeling it'll probably end up handing
you a json blob that you can use jq to play with yourself, but I might add some
convenience functions so you don't have to learn jq. 

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
