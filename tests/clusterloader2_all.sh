#!/bin/bash

USER=${USER:-"kmanaouil"}

KUBECONFIG=${KUBECONFIG:-"~/.kube/config"}
LOGDIR=${LOGDIR:-"/home/$USER/results"}

function sizeoflist() {
	local count=0
	for elem in $1; do
		count=$(($count+1))
	done
	return $count
}


CONFIG_LIST=$(find . -name config.yaml)

if [[ $(sizeoflist ${CONGI_LIST[@]}) -eq 0 ]]; then
	echo "Script must be run from a valid clusterloader2 directory"
	exit 1
fi

for config in $CONFIG_LIST; do 
	export CONFIG=$config
	./clusterloader --kubeconfig=$KUBECONFIG \
		--testconfig=$CONFIG \
		--log_dir=/home/kmanaouil/result \
		--prometheus-scrape-etcd \
		--prometheus-scrape-kube-proxy  \
		--prometheus-scrape-kubelets \
		--prometheus-scrape-node-exporter \
		--alsologtostderr

done
