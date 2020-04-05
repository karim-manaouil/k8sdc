#!/bin/bash

set +e

NamesMap[9090]="0ms"
NamesMap[9094]="50ms"
NamesMap[9098]="250ms"
NamesMap[90912]="400ms"

urlencode() {
	echo "$@" | \
		python3 -c "import sys; import urllib.parse; print(urllib.parse.quote(sys.stdin.read()))"
}

# apiserver_request_error_rate (per minute)

get_error_query() {
	local q="sum by (client, resource,verb,code) (rate(apiserver_request_count{\
		client=~"kube-controller-manager.*|kube-scheduler.*|kubelet.*",\
		resource=~"pods|configmaps",verb=~"POST|GET|LIST", code=~"4.*|5.*"}\[2h]))*60"
	printf %s "$q"
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
	percn_list=(10 20 50 60 90 95 99)
	for percn in ${percn_list[@]}; do
		local query=$(get_percn_query $percn $2)
		local equery=$(urlencode $query)

		curl -X GET \
			"http://localhost:$1/api/v1/query?query=$equery&time=$(date +%s)" && echo
	done	
}

main() {
	get_api_req_percns 9090 "2h"

}

main $@

