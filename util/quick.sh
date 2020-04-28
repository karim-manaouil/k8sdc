#!/bin/bash

# Groupings
GROUP_BY_ALL=$'(le)'
GROUP_BY_RV=$'(le,resource,verb)'


# Components
CLUSTER=$'{component!~\'clusterloader.*|Prometheus.*|operator.*\',verb!=\'WATCH\'}'
MASTER=$'{component=~\'coredns.*|kube-apiserver.*|kube-controller.*|kubectl.*|kube-scheduler.*|cluster-p.*\',verb!=\'WATCH\'}'
WORKERS=$'{component=~\'kubelet.*|kube-proxy.*|calico.*\',verb!=\'WATCH\'}'
KUBELETS=$'{component=~\'kubelet.*\',verb!=\'WATCH\'}'

COMPS=('CLUSTER' 'MASTER' 'WORKERS' 'KUBELETS')

# $1: groupby
# $2: component
run_query() {
    ./jsony.sh --port 8428 --hdb --group-by $1 --filter $2
}

generate_hdb_for_comps(){
    for comp in ${COMPS[@]}; do
        prefix=$(echo $comp | tr '[:upper:]' '[:lower:]')
        run_query $GROUP_BY_ALL ${!comp} > hdb/$1/$prefix/"all.json"
        run_query $GROUP_BY_RV ${!comp}  > hdb/$1/$prefix/"hdb.json"
    done
}

if [[ $# -ne 1 ]]; then
    echo "Provide \$1 please"
    exit 1
fi

generate_hdb_for_comps $1

