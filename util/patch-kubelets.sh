#!/bin/bash

CL2_PATH="/root/go/src/k8s.io/perf-tests/clusterloader2"

create_pki() {
    
    kubectl cp -n monitoring $1 prometheus-k8s-0:/tmp/$2 -c prometheus
}

inject_ssl_certs() {
    pushd /etc/kubernetes/ssl
    create_pki ca.crt ca.crt
    create_pki apiserver-kubelet-client.crt cert.crt
    create_pki apiserver-kubelet-client.key cert.key
    popd
}

patch_endpoints() {
    pushd /root/kubelets
    kubectl apply -f .
    
    nodes=$(kubectl get nodes \
	    -ojsonpath='{.items[*].status.addresses[0].address}')

    for node in ${nodes[@]}; do 
        v=$(echo "${v:-}" && printf "{\"ip\":\"%s\"}," $node); 
    done && \
        A=$(echo $v | sed 's/,$//')
 
    kubectl patch -n monitoring ep kubelets --patch \
        "{\"subsets\": [{\"addresses\": [${A[@]}], \"ports\":\
        [{\"name\":\"proxy-port\",\"port\":10249,\"protocol\":\"TCP\"},\
        {\"name\":\"kubelet-port\",\"port\":10250,\"protocol\":\"TCP\"}]}]}"
    
    popd
}

launch_cl2() {
    pushd $CL2_PATH

    export KUBECONFIG=/root/.kube/config
    export LOG_DIR=/root/log_dir/
    export REPORT_DIR=/root/report_dir/ 
    export MASTERIP=$IP
    export MASTER=$HOSTNAME
    export TESTCONFIG=testing/load/config.yaml

    kubectl apply -f 0promdbpv.yaml

    time ./clusterloader --enable-prometheus-server --provider=skeleton \
        --kubeconfig=$KUBECONFIG --log_dir=$LOG_DIR --report-dir=$REPORT_DIR \
        --master-internal-ip=$MASTERIP --masterip=$MASTERIP --mastername=$MASTER \
        --nodes 100 --testconfig=$TESTCONFIG --alsologtostderr

    popd $CL2_PATH
}

while (( $# )); do
    case $1 in
        --patch)
            PATCH=1
            shift 1
            ;;

        --start)
            START=1
            shift 1
            ;;
        
        --ssl)
            SSL=1
            shift 1
            ;;

        --clean)
            CLEAN=1
            shift 1
            ;;
        *)
            echo "Nothing provided"
            exit 0
            ;;
    esac
done
    if [[ $PATCH -eq 1 ]]; then
        kubectl create ns monitoring
        patch_endpoints
    fi

    if [[ $START -eq 1 ]]; then
        kubectl create ns monitoring
        patch_endpoints
        launch_cl2 1>/tmp/cl2 2>/tmp/cl2 &
        
        while true; do
            state=$(kubectl get pods -n monitoring |grep prometheus-k8s-0 | awk '{print $3}')
            if [[ $state =~ Running ]]; then
                inject_ssl_certs > /tmp/ssl
                echo "SSL certificates injected"
                break
            fi
            sleep 1
        done
    fi

    if [[ $SSL -eq 1 ]]; then
        inject_ssl_certs
    fi

    if [[ $CLEAN -eq 1 ]]; then
        pkill patch-kubelets.sh
        pkill clusterloader
        rm /tmp/cl2
        rm /tmp/ssl
    fi
