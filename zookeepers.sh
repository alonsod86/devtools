#!/bin/bash
NUM_ZOOKEEPERS=3

CONFIG_FILE=$1
VERSION=3.5.2
VOLUME=`pwd`
IMAGE_NAME=zookeeper-noplug
DOCKER=`docker images | grep $IMAGE_NAME | wc -l`
ZK_HOST=`jq -cMSr '.services.zk_userland' $CONFIG_FILE`
SECRETS_PATH=`pwd`/secrets

# build the image if it does not exist
if [ $DOCKER -le 0 ]; then
	echo "Building zookeeper container"
	cd docker/zookeeper
	docker build -t ministratio/$IMAGE_NAME:$VERSION .
fi

# stop the running containers
main=1
port=2
CONNECTION_STRING=""
while [ $main -le $NUM_ZOOKEEPERS ]
do
	echo "Stopping zk-noplug-$main"
	docker rm -f zk-noplug-$main
	CONNECTION_STRING="$CONNECTION_STRING;$ZK_HOST:$port 2888:$port 3888"
	(( main++ ))
	(( port ++ ))
done
CONNECTION_STRING=`echo $CONNECTION_STRING | sed 's/ //g'`
CONNECTION_STRING=`echo ${CONNECTION_STRING:1}`

# run them all
main=1
port=2
while [ $main -le $NUM_ZOOKEEPERS ]
do
	current_port=`echo $port 2181 | sed 's/ //g'`
	docker run -d \
	    --net=host \
	    --name=zk-noplug-$main \
	    -e ZOOKEEPER_SERVER_ID=$main \
	    -e ZOOKEEPER_CLIENT_PORT=$current_port \
	    -e ZOOKEEPER_TICK_TIME=2000 \
	    -e ZOOKEEPER_INIT_LIMIT=5 \
	    -e ZOOKEEPER_SYNC_LIMIT=2 \
	    -e ZOOKEEPER_SERVERS=$CONNECTION_STRING \
	    -e KAFKA_OPTS="-Djava.security.auth.login.config=/etc/kafka/secrets/zk.jaas -Djava.security.krb5.conf=/etc/kafka/secrets/krb.conf -Dzookeeper.authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider -Dsun.security.krb5.debug=true" \
	    -v $SECRETS_PATH:/etc/kafka/secrets \
	    ministratio/$IMAGE_NAME:$VERSION
	(( main++ ))
	(( port ++ ))
done

exit 0