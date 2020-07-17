#!/bin/bash

set +e

declare query

TMP_SSHFS=$(mktemp)

START="2020-05-15T2:00:00.000Z"
END="2020-07-15T16:00:00.000Z"

urlencode() {
	echo "$@" | \
		python3 -c "import sys; import urllib.parse; print(urllib.parse.quote(sys.stdin.read()))"
}

# $1: port
# $query is a global variable
exec_query() {
	local equery=$(urlencode $query)
	curl ${EXTRA:-''} \
		"http://localhost:$1/api/v1/query_range?query=$equery&start=$START&end=$END" && echo
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
		exec_query $1 

	done	
}

api_latency() {
	range="2h"
	clusters=($@)
	mkdir -p out
	for cluster in ${clusters[@]}; do
		get_api_req_percns $cluster $range
		get_api_error_rate $cluster $range 
		get_api_req_rate $cluster $range   
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

# $1: by component ?
get_sum_cdf_query() {
    if [[ -z $1 ]]; then
        comp=""
        by=""
    else
        comp="{component=\"$1\"}"
        by="component"
    fi

    local q="sum by ($by,le) (apiserver_request_duration_seconds_bucket$comp)"
   
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
		exec_query $1 
	done	
}

# $1: groupby
# $2: filter
# $3: metric !
get_hdb_query() {
#    local q="client_request_"      
#    echo $q

    sum_by="sum by $1"

    metric=${3:-"client_request_durations_bucket"}

    local q="$sum_by ($metric$2)"

    echo $q
}

# $1: port
# $2: groupby
# $3: filter
# $4: metric
get_hdb_of() {
    query=$(get_hdb_query $2 $3 $4)
    # printf "executing: %s\n" $query 
    exec_query $1
}

# $1: group
# $2: port
get_all_of() {
    query=$(get_all_query $1)    
    exec_query $2
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
# $1: master
# $2: output
dump_victoria_metrics_snapshot() {
    SNAPSHOT_URL="http://localhost:8428/snapshot/create"

    snapshot_resp=$(ssh root@$1 "curl -s $SNAPSHOT_URL")
    code=$(echo $snapshot_resp | jq '.status')
    
    printf "Trying to generate snapshot" 
    while true; do
        if [[ $code =~ "ok" ]]; then
            break
        fi
        printf "."
        snapshot_resp=$(ssh root@$1 curl -s $SNAPSHOT_URL)
        code=$(echo $snapshot_resp | jq '.status') 
    done

    snapshot_id=$(echo $snapshot_resp | jq '.snapshot')
    printf "\nGenerated snapshot $snapshot_id\n"
    
    r=$(ssh root@$1 "/victoria/vmbackup -storageDataPath=/victoria/data \
        -snapshotName=$snapshot_id -dst=fs:///victoria/backup")
 
    r=$(ssh root@$1 "cd /victoria && zip -r backup.zip backup")

    tarball="$2_$(date +%Y_%m_%d_T%H_%M).zip"
    r=$(scp root@$1:/victoria/backup.zip ./$tarball)

    printf "Generated tarball $tarball for VictoriaMetrics snapshot $snapshot_id\n"  
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
            --metric)
                METRIC=$2
                shift 2
                ;;
            --filter)
                FILTER=$2
                shift 2
                ;;
            --group-by)
                GROUPBY=$2
                shift 2
                ;;
            --cdf)
                CDF=1
                shift 1
                ;;
            --prometheus)
                PPATH=$2
                shift 2
                ;;
            --victoria)
                VMPATH=$2
                shift 2
                ;;
            --prom-snapshot)
                PROM_SNAPSHOT=$2
                shift 2
                ;;
            --vm-snapshot)
                VM_SNAPSHOT=$2
                shift 2
                ;;
            --output)
                OUTPUT=$2
                shift 2
                ;;
            --extra)
                EXTRA=$2
                shift 2
                ;;
            *)
               echo "unknown option $1"
               exit 1 
        esac                                
    done   

    if [[ $HDB -eq 1 ]]; then
        get_hdb_of $PORT $GROUPBY $FILTER $METRIC 
    fi

    if [[ $CDF -eq 1 ]]; then 
        api_latency_cdf $PORT
    fi

    if [[ $TOPK -ne 0 ]]; then
        get_topk_req_count $PORT $TOPK 
    fi
 
    if [[ -v PPATH ]]; then
        docker run --env GOGC=80 --rm -p 9090:9090 -uroot -v "$PWD/$PPATH":"/prometheus" prom/prometheus \
            --config.file=/etc/prometheus/prometheus.yml \
            --storage.tsdb.path=/prometheus

    elif [[ -v VMPATH ]]; then
        cp $VMPATH victoria
        pushd victoria
        unzip `basename $VMPATH`
        ./vmrestore -src=fs://$PWD/backup -storageDataPath=$PWD/data
        ./victoria-bin -storageDataPath $PWD/data
        rm -rf backup data
        rm `basename $VMPATH`
        popd
    fi

    if [[ -v PROM_SNAPSHOT ]]; then
        dump_prometheus_snapshot $PROM_SNAPSHOT $OUTPUT
    fi

    if [[ -v VM_SNAPSHOT ]]; then
        dump_victoria_metrics_snapshot $VM_SNAPSHOT $OUTPUT
    fi
}

main $@
