#!/bin/bash

kubectl apply -f ./lserver/
kubectl apply -f ./lclient/

gauges=(5 10 50 100 200 500 1000 900 500 200 0)
gauge=0

while true; do
	current=${gauges[$gauge]}
	kubectl scale deployment loadclient --replicas=$current -n loadbench
	
	running=$(kubectl get pods -n loadbench | grep "loadclient" | awk '{print $3}' | grep -c "Running")
	while [ $running -lt $current ]; do
		sleep 3
		running=$(kubectl get pods -n loadbench | grep "loadclient" | awk '{print $3}' | grep -c "Running")
	done

	if [ $current -eq 0 ]; then
		gauge=0
		kubectl delete ns loadbench
		kubectl apply -f ./lserver/
		kubectl apply -f ./lclient/
	else
		gauge=$(($gauge+1))
	fi
done
