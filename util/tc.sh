#!/bin/bash

set +e

# $1: src
# $2: delay in ms
do_tc() {
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "Arguments error when calling do_tc"
		exit 1
	fi
	
	ssh root@${1} tc qdisc add dev ens3 root handle 1: prio
	ssh root@${1} tc qdisc add dev ens3 parent 1:1 handle 2: netem delay ${2}ms
}

# $1: src
# $2: dst
add_tc_filter() {
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "Arguments error when calling do_tc"
		exit 1
	fi

	ssh root@${1} tc filter add dev ens3 parent 1:0 protocol ip pref 55 handle ::55 u32 match ip dst ${2} flowid 2:1
}

# Symmetric master to site tc
# $1: master
# $2: site[@]
tc_master_to_site_sym() {
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "Arguments error when calling tc_master_to_site"
		exit 1
	fi

	local nodes=("${!2}")

	for node in ${nodes[@]}; do
		add_tc_filter $1 $node 2>/dev/null
		add_tc_filter $node $1 2>/dev/null
		printf "%s " $node
	done
}

# $1: src site[@]
# $2: dst site[@]
# $3: delay in ms
tc_site_to_site_sym() {
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
		echo "Arguments error when calling tc_master_to_site"
		exit 1
	fi

	local ssite=("${!1}")

	for snode in ${ssite[@]}; do
		printf "%s" $snode
		( # concurrent subshell processes
			do_tc $snode $3
			tc_master_to_site_sym $snode $2
		) &
		echo
	done
}

parse_arguments() 
{
    while (( $# )); do
        case $1 in
             --src)
                IFS=: read -r -a comps <<< "$2"
                for comp in ${comps[@]}; do
                    SRC_COMPS+=("$comp")
                done
                unset comp
                shift 2
                ;;

            --dst)
                IFS=: read -r -a comps <<< "$2"
                for comp in ${comps[@]}; do
                    DST_COMPS+=("$comp")
                done
                unset comp
                shift 2
                ;;

           --delay)
                DELAY=$2
                shift 2
                ;;
            *)
               echo "unknown option $1"
	       exit 1 
        esac                                
    done   
}

# Usage: ./tc.sh --src PREFIX:START:END --dst PREFIX:START:END --delay MS
# e.g. ./tc.sh --src 10.158.0:2:2 10.158.0:3:100 50
# it will apply a 50ms delay between 10.158.0.2 and 10.158.0.{3-100}
main() {
	parse_arguments $@

	src=()
	for i in `seq ${SRC_COMPS[1]} ${SRC_COMPS[2]}`; do 
		src+=("${SRC_COMPS[0]}.$i")	
	done

	dst=()
	for i in `seq ${DST_COMPS[1]} ${DST_COMPS[2]}`; do 
		dst+=("${DST_COMPS[0]}.$i")	
	done

	tc_site_to_site_sym src[@] dst[@] $DELAY
}

main $@

