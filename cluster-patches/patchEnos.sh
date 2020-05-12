#!/bin/bash

cp cli.py $1/lib/python3.7/site-packages/enos_kubernetes/
cp tasks.py $1/lib/python3.7/site-packages/enos_kubernetes/
cp constants.py $1/lib/python3.7/site-packages/enos_kubernetes/

for f in prepare_env_all.yml prepare_env.yml prepare_exp.yml cleanup_exp.yml; do
       cp $f $1/lib/python3.7/site-packages/enos_kubernetes/ansible
done       
