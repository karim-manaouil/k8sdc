#!/bin/bash

USER=${USER:-"kmanaouil"}

KUBECONFIG=${KUBECONFIG:-"~/.kube/config"}
LOGDIR=${LOGDIR:-"/home/$USER/results"}

sizeoflist (){
	count=0
	for elem in $1; do
		count=$(($count+1))
	done
	echo $count
	return $count
}


if [[ "$CONFIGS" =~ "ALL" ]]; then
	export CONFIGS=$(find . -name config.yaml)
fi

if [[  sizeoflist ${CONFIGS[@]} -eq 0 ]]; then
	echo "Script must be run from a valid clusterloader2 directory"
	exit 1
fi


for config in $CONFIGS; do 
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
