#!/bin/bash

MASTER_ID=`docker ps | grep minimesos-master | awk '{ print $1}'`
MASTER_IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $MASTER_ID`

echo "frameworkId=$1" | curl -d@- -X POST http://$MASTER_IP:5050/master/teardown

