#!/bin/bash

F="kube-$1"
PS=$(docker ps | grep "k8s_$F" | awk '{ print $1 }')
POD=$(kubectl get -owide -n kube-system pods| grep $F | grep $IP | awk '{ print $1 }')

echo $F
echo $PS
echo $POD

kubectl exec -it -n kube-system pod/$POD -- rm /usr/local/bin/$F
kubectl cp -n kube-system $F $POD:/usr/local/bin/$F

docker commit $PS "gcr.io/google-containers/$F:v1.16.3"
docker save "gcr.io/google-containers/$F:v1.16.3" -o ../$F.tar
