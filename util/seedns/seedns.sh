#!/bin/bash

NS="-n seedns"

NODES=""
TYPES=("Headless" "ClusterIP")

BENCHS=('SINGLE' 'DAEMON' 'LOADED')

SCALE=10

SINGLE="1"
DAEMON=""
LOADED=""

SVC_FILE=$(mktemp)
PROBE_FILE=$(mktemp)

get_nodes() {
    NODES=$(kubectl get nodes | nl | tail -1 | awk '{print $1}')
    NODES=$(($NODES-1))
}

init_params() {
    get_nodes
    DAEMON=$NODES
    LOADED=$(($NODES*$SCALE))
}

create_headless_svc() {
    cat > $SVC_FILE <<EOL
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80 
EOL
}

# $1: svc name
# $2: selector
create_clusterip_svc() {
     cat > $SVC_FILE <<EOL
apiVersion: v1
kind: Service
metadata:
  name: $1
spec:
  selector:
    app: $2
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80 
EOL
   
}

create_probe_nodeport() {
    cat > $SVC_FILE <<EOL
apiVersion: v1
kind: Service
metadata:
  name: seedns-probe
spec:
  type: NodePort
  selector:
    app: seedns-probe
    clone: main-seedns
  ports:
    - port: 8998
      targetPort: 8998
      nodePort: 30007
EOL

    kubectl apply $NS -f $SVC_FILE
}

create_probe_file() {
    RVAL=$2
    HOST=$3

    if [ "$1" = "seedns-probe" ]; then
        clone="clone: main-seedns"
    else
        clone=""
    fi

    cat > $PROBE_FILE <<EOL
apiVersion: v1
kind: Pod
metadata:
  name: $1
  labels:
    app: seedns-probe 
    $clone 
spec:
  containers:
  - name: seedns-probe
    image: afr0ck/load:seedns
    imagePullPolicy: Always
    securityContext:
        privileged: true
    env:
    - name: seednsROUNDS
      value: "$RVAL"
    - name: seednsHOSTNAME
      value: "$HOST"
EOL
}

# $1: NAME
# $2: RVAL
# $3: HOST
create_dns_probe() {
    create_probe_file $1 $2 $3
    echo "$PROBE_FILE created"
    kubectl apply $NS -f $PROBE_FILE
}

# $1: type
# $2: name
# $3: selector
create_service() {    
    if [ "$1" = "Headless" ]; then
        create_headless_svc
        echo "Headless svc $SVC_FILE created"
    else
        create_clusterip_svc $2 $3
        echo "ClusterIP svc $SVC_FILE created"

    fi

    kubectl apply $NS -f "$SVC_FILE"
}

# $1: RVAL
add_noise() {
    local svc_name="noise$(($RANDOM*$RANDOM))"
    local probe_name="probe-$(($RANDOM*$RANDOM))"
	
    create_service "ClusterIP" $svc_name "nothing"
    create_dns_probe $probe_name $1 "$svc_name.seedns.svc.cluster.local"
}


create_deployment() {
    kubectl create $NS deployment nginx --image=nginx
    kubectl scale $NS "--replicas=$1" deployment nginx
}

# $1: deployment
wait_deployment() {
	while true; do
		status=$(kubectl get pods | grep seedns-probe | awk '{print $3}')
		if [ "$status" = "Running" ]; then
			return 0
		fi
	done
}

# $1: type
# $2: replicas
run_bench() {
    create_service $1 "nginx" "nginx"
    create_deployment $2
     
    create_dns_probe "seedns-probe" 100 "nginx.seedns.svc.cluster.local"
    
    for s in $(seq 1 $2); do
        add_noise 100
    done
}

destroy_bench() {
    kubectl delete ns seedns 
}

locate_seedns() {
    local ip=$(kubectl $NS describe pod/seedns-probe | grep Node: | cut -d'/' -f2)

    printf "%s" $ip
}

wait_for_bench() {    
    while true; do
	local ip=$(locate_seedns)
    	local status=$(curl -s $ip:30007/stop)
        if [ "$status" = "true" ]; then
            return 0
        fi
	printf "." >&2
	sleep 5
    done
}

gather_series() {
    local ip=$(locate_seedns)
    local status=$(curl -s $ip:30007/metrics)

    echo "$status"
}

# $1: type
run_benchs_for_type() {
    for bench in ${BENCHS[@]}; do
    	kubectl create ns seedns
    	create_probe_nodeport
        echo "Running bench [$1, $bench]" >&2
        run_bench $1 ${!bench}
	echo "Waiting for benchmark to finish" >&2
        wait_for_bench
	echo "Gathering results" >&2
        gather_series > "$1_$bench.res"
        echo "Bench finished running. Check $1_$bench.res" >&2
        destroy_bench
    done
}

run_benchs() {
    for t in ${TYPES[@]}; do
        run_benchs_for_type $t
    done
}

main() {
    init_params
    run_benchs
}

main
