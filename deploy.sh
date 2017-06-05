#!/bin/bash

CONFIG_FILE=$2
JRE_BIN=jre-8u112-linux-x64.tar.gz
KFK_BIN=kafka_2.11-0.10.0.1.tgz

if [ -z "$1" ]
  then
    echo "Specify host's network interface and config file"
    echo "      ./deploy.sh enp2s0 config.json"
    exit 1
fi

PYTHON_PORT=`jq -cMSr '.deploy.port' $CONFIG_FILE`
INNET_ADDR=`jq -cMSr '.deploy.eth' $CONFIG_FILE`
SOURCES=`jq -cMSr '.deploy.sources' $CONFIG_FILE`
HOST_IP=`ifconfig $1 | grep "$INNET_ADDR" | cut -d: -f2 | awk '{ print $1}'`

echo "Preparing environment"
count=0
max=`jq -r ".scheduler[] | ." $CONFIG_FILE | wc -l`
keys=`jq -r ".scheduler" $CONFIG_FILE | jq 'keys'`
while [ $count -lt $max ]
do
	key=`jq -r ".scheduler" $CONFIG_FILE | jq 'keys' | jq .[$count] | sed 's/\"//g'`
	val=`jq -r ".scheduler" $CONFIG_FILE | jq ".$key" | sed 's/\"//g'`
	echo "Setting $key to $val"
	export $key=$val
	(( count++ ))
done

export JAVA_URI=http://$HOST_IP:$PYTHON_PORT/kafka/jre-8u112-linux-x64.tar.gz
export KAFKA_URI=http://$HOST_IP:$PYTHON_PORT/kafka/kafka_2.11-0.10.0.1.tgz
export OVERRIDER_URI=http://$HOST_IP:$PYTHON_PORT/kafka/overrider.zip
export SCHEDULER_URI=http://$HOST_IP:$PYTHON_PORT/kafka/scheduler.zip
export EXECUTOR_URI=http://$HOST_IP:$PYTHON_PORT/kafka/executor.zip

#echo "Cloning dcos-kafka-service"
#cd kafka 
#git clone git@github.com:Stratio/dcos-kafka-service.git
#git checkout feature/

echo "Gathering resources"
cp $SOURCES/kafka-scheduler/build/distributions/scheduler.zip kafka/scheduler.zip
cp $SOURCES/kafka-executor/build/distributions/executor.zip kafka/executor.zip
cp $SOURCES/kafka-config-overrider/build/distributions/overrider.zip kafka/overrider.zip
cp -R $SOURCES/kafka-scheduler/build/install/scheduler/ kafka/

if [ ! -f "kafka/$JRE_BIN" ]; then 
	wget https://downloads.mesosphere.com/kafka/assets/$JRE_BIN
	mv $JRE_BIN kafka/$JRE_BIN
fi
if [ ! -f "kafka/$KFK_BIN" ]; then 
	wget http://apache.uvigo.es/kafka/0.10.0.1/kafka_2.11-0.10.0.1.tgz
	mv kafka_2.11-0.10.0.1.tgz kafka/kafka_2.11-0.10.0.1.tgz
fi

echo "Verifying python server"
PYTHON_SERVER=`netstat -plnt | grep $PYTHON_PORT | wc -l`
if [ $PYTHON_SERVER -eq 0 ]; then
	echo "Launching pyhton server"
	python -m SimpleHTTPServer $PYTHON_PORT &
fi

echo "Launching dcos-kafka-service scheduler"
kafka/scheduler/bin/kafka-scheduler server kafka/scheduler/conf/scheduler.yml
