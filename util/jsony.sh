#!/bin/bash

set +e

NamesMap[9090]="0ms"
NamesMap[9025]="25ms"
NamesMap[9094]="50ms"
NamesMap[9098]="250ms"
NamesMap[9012]="400ms"

TMP_SSHFS="/tmp/vvvvvvvvvvvvsshfs"

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

api_latency() {
	range="2h"
	clusters=($@)
	mkdir -p out
	for cluster in ${clusters[@]}; do
		get_api_req_percns $cluster $range
		get_api_error_rate $cluster $range > "out/${NamesMap[$cluster]}""_error.json"
		get_api_req_rate $cluster $range   > "out/${NamesMap[$cluster]}""_rate.json"
	done
}

# $1: K (default 50)
get_topk_req_count_query() {
    local q="topk(${1:-50},sum by(resource, verb) (apiserver_request_count))"
    
    echo $q
}

# $1: port
# $2: K (default 50)
get_topk_req_count() {
    query=$(get_topk_req_count_query $2)
  	exec_query $1
}

# CDF logic
# $1: resource
# $2: verb
get_cdf_query() {
	local q="sum by (le,resource,verb) \
		(apiserver_request_duration_seconds_bucket{resource=~\"$1\",verb=~\"$2\"})"
	
	echo $q
}

get_sum_cdf_query() {
	local q="sum by (le) (apiserver_request_duration_seconds_bucket)"

	echo $q

}

# $1: port
api_latency_cdf() {
    verbs=(LIST GET POST PATCH)
    resources=(deployments replicasets statefulsets pods configmaps services)

    pairs=("SUM/sum")
    for r in ${resources[@]}; do
        for v in ${verbs[@]}; do
            pairs+=("$v/$r")
        done
    done

	path=cdf/${NamesMap[$1]}

	mkdir -p "$path"

	for pair in ${pairs[@]}; do
		resource=$(echo $pair | cut -d'/' -f2)
		verb=$(echo $pair | cut -d'/' -f1)

		mkdir -p "$path/$resource"
		if [[ "$verb" =~ "SUM" ]]; then
			query=$(get_sum_cdf_query)
		else
			query=$(get_cdf_query $resource $verb)
		fi
		exec_query $1 > "$path/$resource/$verb"".json"
	done	
}

get_hdb_query() {
    local q="sum by (le,component,resource,verb) (apiserver_request_duration_seconds_bucket)"

    echo $q
}

# $1: port
get_hdb_of() {
    query=$(get_hdb_query)
    exec_query $1
}

# $1: client
# $2: hdb
group_by_client() {
    jq <$2 \
        ".data.result=[.data.result[] | select(.metric.component | contains(\"$1\"))]"
}

# $1: master ip
# $2: db name
dump_prometheus_snapshot() {
    SNAPSHOT_URL_B64="aHR0cDovL2xvY2FsaG9zdDo4MDAxL2FwaS92MS9uYW1lc3BhY2VzL21vb\
        ml0b3Jpbmcvc2VydmljZXMvaHR0cDpwcm9tZXRoZXVzLWs4czo5MDkwL3Byb3h5L2FwaS92\
        MS9hZG1pbi90c2RiL3NuYXBzaG90Cg=="

    SNAPSHOT_URL=$(echo "$SNAPSHOT_URL_B64" | sed 's/ //g' | base64 --decode)

    snapshot_resp=$(ssh root@$1 "curl -s -X POST $SNAPSHOT_URL")
    code=$(echo $snapshot_resp | jq '.status')
    
    printf "Trying to generate snapshot" 
    while true; do
        if [[ $code == *"success"* ]]; then
            break
        fi
        printf "."
        snapshot_resp=$(ssh root@$1 curl -s -X POST $SNAPSHOT_URL)
        code=$(echo $snapshot_resp | jq '.status') 
    done

    snapshot_id=$(echo $snapshot_resp | jq '.data.name')
    printf "\nGenerated snapshot $snapshot_id\n"

    POD="pod/prometheus-k8s-0"
    get_db_host="kubectl describe -n monitoring $POD | grep -E \"^Node:\" | awk '{print \$2}' | cut -d\"/\" -f 2"
    db_host=$(ssh root@$1 "$get_db_host")

    set +e
    mkdir -p $TMP_SSHFS
    
    echo "mounting remote TSDB host"
    r=$(sshfs root@$db_host:/tmp/prometheus-db/snapshots/ $TMP_SSHFS)
    snapshot_id="${snapshot_id%\"}"
    snapshot_id="${snapshot_id#\"}"
    
    pushd $TMP_SSHFS
    tar cvjf $2 $snapshot_id
    popd

    sudo umount $TMP_SSHFS
    rmdir $TMP_SSHFS
    set -e

    printf "Generated tarball $2 for prometheus snapshot $snapshot_id\n" 
}

main() {
    TOPK=0
    HDB=0
    while (( $# )); do
        case $1 in
             --port)
                PORT=$2 
                shift 2
                ;;
            --topk)
                TOPK=$2
                shift 2
                ;;
            --hdb)
                HDB=1
                shift 1
                ;;

            --cdf)
                CDF=1
                shift 1
                ;;
            --by-client)
                CLIENT=$2
                shift 2
                ;;
            --prometheus)
                PPATH=$2
                shift 2
                ;;
            --snapshot)
                SNAPSHOT=$2
                shift 2
                ;;
            --output)
                OUTPUT=$2
                shift 2
                ;;
            *)
               echo "unknown option $1"
               exit 1 
        esac                                
    done   

    [[ $HDB -eq 1 ]] && get_hdb_of $PORT >> "hdb_${NamesMap[$PORT]}.json"

    if [[ $CDF -eq 1 ]]; then 
        api_latency_cdf $PORT
    fi

    if [[ $TOPK -ne 0 ]]; then
        get_topk_req_count $PORT $TOPK > "top$TOPK""_""${NamesMap[$PORT]}count.json"
    fi

    if [[ -v CLIENT ]]; then 
        for hdb in ./by_client/all/*; do
            path="./by_client/$CLIENT"
            new_hdb=$(basename $hdb)
            [ ! -d "$path" ] && mkdir -p $path

            group_by_client "$CLIENT" "$hdb" > "$path/$new_hdb"
        done
    fi

    if [[ -v PPATH ]]; then
        docker run --rm -p 9090:9090 -uroot -v $PWD/$PPATH:/prometheus prom/prometheus \
            --config.file=/etc/prometheus/prometheus.yml \
            --storage.tsdb.path=/prometheus
    fi

    if [[ -v SNAPSHOT ]]; then
        dump_prometheus_snapshot $SNAPSHOT $OUTPUT
    fi
}

main $@
