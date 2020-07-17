#!/bin/bash

set -e


copy_binaries() {
    scp server "root@$1.2":
    for i in $(seq 3 12); do
        scp client "root@$1.$i":
    done
}

finish_experiment() {
    kill $(ps ax  | grep 'of=BigFile.*server' | head -1 | awk '{ print $1 }') 1>/dev/null 2>/dev/null
    for pid in $(ps ax | grep "pkill client" | awk '{print $1}'); do kill $pid 1>/dev/null 2>/dev/null; done
}

main() {
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
            -CYCLES)
                C=$2
                shift 2
                ;;
            -QPS)
                Q=$2
                shift 2
                ;;
            -BREAK)
                B=$2
                shift 2
                ;;
            -PAUSE)
                P=$2
                shift 2
                ;;
            --size)
                size=$2
                shift 2
                ;;
            --copy)
                copy_binaries $2
                exit 0
                ;;
            --clean)
                CLEAN=1
                shift 1
                ;;
        esac
    done

    echo "Starting experiment"
    rm -rf 10.*

    if [[ $CLEAN -eq 1 ]]; then
        finish_experiment
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
        finish_experiment
    set -e
    $SSH "dd if=/dev/urandom of=BigFile bs=${size:-8192} count=1 && ./server" 1>log_server 2>&1 &
    echo "Server launched"

    # Launching experiment
    for i in `seq 3 12`; do
        ssh "root@$client.$i" "pkill client || ulimit -n $((1024*1024)) && ulimit -a && sleep 1 && SRVIP=http://$SERVER:8998/serv CYCLES=$C QPS=$Q BREAK=$B PAUSE=$P ./client" 1>log_client_$i 2>&1 & 
        pids[${i}]=$!
    done

    for pid in ${pids[*]}; do
        wait $pid
    done
    
    sleep 2
    echo "Finishing experiment"
    finish_experiment
}   

main $@
