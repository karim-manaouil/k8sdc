#!/bin/bash

while true; do
	curl $LOADSERVER/register?host=$HOSTNAME&date=$(date)
	sleep 5
done
