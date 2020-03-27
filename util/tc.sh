#!/bin/bash

set +e

do_tc() {
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
		echo "Arguments error when calling do_tc"
		exit 1
	fi
	
	ssh root@${1} tc qdisc del dev ens3 root
	ssh root@${1} tc qdisc add dev ens3 root handle 1: prio
	ssh root@${1} tc qdisc add dev ens3 parent 1:1 handle 2: netem delay ${3}ms
	ssh root@${1} tc filter add dev ens3 parent 1:0 protocol ip pref 55 handle ::55 u32 match ip dst ${2} flowid 2:1
}

# Symmetric master to site tc
tc_master_to_site_sym() {
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
		echo "Arguments error when calling tc_master_to_site"
		exit 1
	fi

	local nodes=("${!2}")

	for node in ${nodes[@]}; do
		do_tc $1 $node 2 > /dev/null
		do_tc $node $1 2 > /dev/null
	done
}

main() {
   	master=$1
	prefix=$2
	delay=$3

	site=()
	for i in `seq 3 101`; do 
		site+=("$prefix.$i")	
	done

	tc_master_to_site_sym $master site[@] $delay

}

if [ -z "$1" ] || [ -z "$2" ]; then
       echo "Arguments error"
       exit 1
fi

main $1 $2 $3

