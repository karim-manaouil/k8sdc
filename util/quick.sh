#!/bin/bash

# Groupings
GROUP_BY_ALL=$'(le)'
GROUP_BY_RV=$'(le,resource,verb)'


# Components
CLUSTER=$'{component!~\'clusterloader.*|Prometheus.*|operator.*\',verb!=\'WATCH\'}'
MASTER=$'{component=~\'coredns.*|kube-apiserver.*|kube-controller.*|kubectl.*|\
		kube-scheduler.*|cluster-p.*\',verb!=\'WATCH\'}'
WORKERS=$'{component=~\'kubelet.*|kube-proxy.*|calico.*\',verb!=\'WATCH\'}'
KUBELETS=$'{component=~\'kubelet.*\',verb!=\'WATCH\'}'
APISERVER=$'{component=~\'kube-apiserver.*\',verb!=\'WATCH\'}'
SCHEDULER=$'{component=~\'kube-scheduler.*\',verb!=\'WATCH\'}'
CONTROLLERS=$'{component=~\'kube-controller.*\',verb!=\'WATCH\'}'

COMPS=('MASTER' 'WORKERS')

# $1: groupby
# $2: component
run_query() {
    ./jsony.sh --extra "-s" --port 8428 --hdb --group-by $1 --filter $2
}

# $1: latency
generate_hdb_for_comps(){
    for comp in ${COMPS[@]}; do
        prefix=$(echo $comp | tr '[:upper:]' '[:lower:]')
        run_query $GROUP_BY_ALL ${!comp} > hdb/$1/$prefix/"all.json"
        run_query $GROUP_BY_RV ${!comp}  > hdb/$1/$prefix/"hdb.json"
        echo "Processed (ALL, $prefix) / (RV, $prefix)"
    done
}

print_percn_table(){
    printf "percn\t\t master/k8s\t\t workers/k8s\t\t kubelets/workers\n"

    for i in 0 25 50 250 400; do
        cluster_n=$(cat hdb/$i/cluster/all.json | \
            jq '.data.result[] | select(.metric.le | contains("+Inf")) | .values[]' | \
            tail -2 | head -1 | sed 's/"//g' | xargs) 
        master_n=$(cat hdb/$i/master/all.json | \
            jq '.data.result[] | select(.metric.le | contains("+Inf")) | .values[]' | \
            tail -2 | head -1 | sed 's/"//g' | xargs)
        workers_n=$(cat hdb/$i/workers/all.json | \
            jq '.data.result[] | select(.metric.le | contains("+Inf")) | .values[]' | \
            tail -2 | head -1 | sed 's/"//g' | xargs)
        kubelets_n=$(cat hdb/$i/kubelets/all.json | \
            jq '.data.result[] | select(.metric.le | contains("+Inf")) | .values[]' | \
            tail -2 | head -1 | sed 's/"//g' | xargs)
    
    n1=$(echo $master_n/$cluster_n*100 | bc -l)
    n2=$(echo $workers_n/$cluster_n*100 | bc -l) 
    n3=$(echo $kubelets_n/$workers_n*100 | bc -l)

    printf "%dms\t\t %f\t\t %f\t\t %f\n" $i $n1 $n2 $n3 
done


}

case $1 in
    --generate)
        generate_hdb_for_comps $2
        ;;
    --get-percn)
        print_percn_table && echo
        ;;
    *)
        echo "unknown option $1"
        exit 1
esac    
