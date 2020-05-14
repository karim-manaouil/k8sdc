#!/bin/bash

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
    
    nodes=$(kubectl get nodes -ojsonpath=\
        '{.items[*].status.addresses[0].address}')

    for node in ${nodes[@]}; do 
        v=$(echo "${v:-}" && printf "{\"ip\":\"%s\"}," $node); 
    done && \
        A=$(echo $v | sed 's/,$//')

    kubectl patch -n monitoring ep kubelets --patch \
        "{\"subsets\": [{\"addresses\": [$A], \"ports\":\
        [{\"name\":\"proxy-port\",\"port\":10249,\"protocol\":\"TCP\"},\
        {\"name\":\"kubelet-port\",\"port\":10250,\"protocol\":\"TCP\"}]}]}"
    
    popd
}

launch_cl2() {
    pushd $CL2_PATH

    export \
        KUBECONFIG=/root/.kube/config; export LOG_DIR=/root/log_dir/; export \
        REPORT_DIR=/root/report_dir/ ; export MASTERIP=$IP; export \
        MASTER=$HOSTNAME; export TESTCONFIG=testing/load/config.yaml

    time ./clusterloader --enable-prometheus-server --provider=skeleton \
        --kubeconfig=$KUBECONFIG --log_dir=$LOG_DIR --report-dir=$REPORT_DIR \
        --master-internal-ip=$MASTERIP --masterip=$MASTERIP --mastername=$MASTER \
        --nodes 100 --testconfig=$TESTCONFIG --alsologtostderr

    popd $CL2_PATH
}

while (( $# )); do
    case $1 in
        --start)
            START=1
            shift 1
            ;;
        
        --ssl)
            SSL=1
            shift 1
            ;;
        *)
            echo "Nothing provided"
            exit 0
            ;;
    esac
done

    if [[ $START -eq 1 ]]; then
        kubectl create ns monitoring
        patch_endpoints
        launch_cl2
    fi

    if [[ $SSL -eq 1 ]]; then
        inject_ssl_certs
    fi
