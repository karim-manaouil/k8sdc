#!/bin/bash

set +e

NamesMap[9090]="0ms"
NamesMap[9094]="50ms"
NamesMap[9098]="250ms"
NamesMap[90912]="400ms"

declare query

urlencode() {
	echo "$@" | \
		python3 -c "import sys; import urllib.parse; print(urllib.parse.quote(sys.stdin.read()))"
}

# $1: port
# $query is a global variable
exec_query() {
	local equery=$(urlencode $query)
	curl -X GET -s \
		"http://localhost:$1/api/v1/query?query=$equery&time=$(date +%s)" && echo
}

# apiserver_request_error_rate (per minute)

# $1: time range
get_error_query() {
	local q="sum by (client, resource,verb,code) (rate(apiserver_request_count{\
		client=~\"kube-controller-manager.*|kube-scheduler.*|kubelet.*\",\
		resource=~\"pods|configmaps\",verb=~\"POST|GET|LIST\", code=~\"4.*|5.*\"}\
		[$1]))*60"
	printf %s "$q"
}

# $1: port
# $2: time range
get_api_error_rate() {
	query=$(get_error_query $2)
	exec_query $1
}


# apiserver_request_rate

# $1: range
get_req_rate_query() {
	local q="sum(rate(apiserver_request_duration_seconds_count\
		{resource=~\"pods|configmaps\",verb=~\"POST|GET|LIST\"}[$1])) \
			by (resource,verb, le)*1000"
	printf "%s" $q
}

# $1: port
# $2: time range
get_api_req_rate() {
	query=$(get_req_rate_query $2)
	exec_query $1
}


# apiserver_request_duration_histogram (in ms)

# $1: percentile
# $2: time range
get_percn_query() {
	local q="histogram_quantile($1, sum(rate(\
		apiserver_request_duration_seconds_bucket{resource=~\"pods|configmaps\",\
		verb=~\"POST|GET|LIST\"}[$2])) by (resource,verb, le))*1000"
	printf %s "$q"
}

# $1: port
# $2: time range
get_api_req_percns() {
	percn_list=(0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 0.95 0.99)
	for percn in ${percn_list[@]}; do
		query=$(get_percn_query $percn $2)
		postfix=$(echo $percn | sed 's/0.//')
		exec_query $1 > "out/${NamesMap[$1]}""_percn_"$postfix".json" 

	done	
}

main() {
	range="12h"
	clusters=($@)
	mkdir -p out
	for cluster in ${clusters[@]}; do
		get_api_req_percns $cluster $range
		get_api_error_rate $cluster $range > "out/${NamesMap[$cluster]}""_error.json"
		get_api_req_rate $cluster $range   > "out/${NamesMap[$cluster]}""_rate.json"
	done
}

main $@

