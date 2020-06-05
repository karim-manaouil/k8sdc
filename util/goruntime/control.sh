#!/bin/bash

set -e

main() {
    TOPK=0
    HDB=0
    while (( $# )); do
        case $1 in
             --server)
                SERVER=$2 
                shift 2
                ;;
            --baseline)
                BASE=1
                shift 1
                ;;
            --wanwide)
                WAN=1
                shift 1
                ;;
            --interface)
                int=$2
                shift 2
                ;;
            --delay)
                delay=$2
                shift 2
                ;;
            -C)
                C=$2
                shift 2
                ;;
            -R)
                R=$2
                shift 2
                ;;
            -W)
                W=$2
                shift 2
                ;;
            --size)
                size=$2
                shift 2
                ;;
            --clean)
                CLEAN=1
                shift 1
                ;;
        esac
    done

    if [[ $CLEAN -eq 1 ]]; then
        kill $(ps ax  | grep "of=BigFile.*server" | head -1 | awk '{ print $1 }')
        rm 10.*
        exit 0
    fi 

    SSH="ssh root@$SERVER"

    client=${SERVER%.*}

    if [[ $BASE -eq 1 ]]; then
        set +e
        $SSH "tc qdisc del dev $int root"
        set -e
    elif [[ $WAN -eq 1 ]]; then
        set +e
        $SSH "tc qdisc del dev $int root"
        set -e
        $SSH "tc qdisc add dev $int root handle 1: prio"
        $SSH "tc qdisc add dev $int parent 1:1 handle 2: netem delay $delay"        
                
        for i in `seq 3 9`; do
            $SSH "tc filter add dev $int parent 1:0 protocol ip prio 1 u32 match ip dst $client.$i flowid 2:1"
        done 
    fi
   
    set +e 
    kill $(ps ax  | grep "of=BigFile.*server" | head -1 | awk '{ print $1 }')
    set -e
    $SSH "dd if=/dev/urandom of=BigFile bs=${size:-8192} count=1 && ./server" > "$SERVER.log" 2>&1 &
    echo "Server launched"

    # Launching experiment
    for i in `seq 3 12`; do
        ssh "root@$client.$i" "ulimit -n $((1024*1024)) && sleep 1 && SRVIP=http://$SERVER:8998/serv C=$C R=$R W=$W ./client" > "$client.$i.log" 2>&1 &
        echo "$client.$i started"
    done
}   

main $@
