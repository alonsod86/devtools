#!/bin/bash

# Check for aguments
if [ -z "$1" ]
  then
    echo "Specify mode (producer|consumer) and reset flag (optional)"
    echo "      ./testing.sh producer false"
    exit 1
fi

RESET=$2
CONFIG_FILE=config.json
KFK_BIN=kafka_2.11-0.10.0.1

if [ "$RESET" == "true" ]; then
	# decompress kafka
	echo "Expanding kafka binaries"
	cd kafka
	rm -rf binaries
	tar zxf $KFK_BIN.tgz
	mv $KFK_BIN binaries/
	cd ..

	count=0
	max=`jq -r ".clients.config[] | ." $CONFIG_FILE | wc -l`
	keys=`jq -r ".clients.config" $CONFIG_FILE | jq 'keys'`
	while [ $count -lt $max ]
	do
		key=`jq -r ".clients.config" $CONFIG_FILE | jq 'keys' | jq .[$count] | sed 's/\"//g'`
		val=`jq -r ".clients.config" $CONFIG_FILE | jq ".$key" | sed 's/\"//g'`
		
		key=`echo $key | sed 's/_/\./g'`
		echo "Setting $key to $val"
		echo "$key=$val" >> kafka/binaries/config/producer.properties
		echo "$key=$val" >> kafka/binaries/config/consumer.properties
		(( count++ ))
	done
fi

CONSUMER_BIN=`jq -r ".clients.consumer" $CONFIG_FILE`
PRODUCER_BIN=`jq -r ".clients.producer" $CONFIG_FILE`

if [ "$1" == "producer" ]; then
	echo "Starting producer"
	sh $PRODUCER_BIN
else 
	echo "Starting consumer"
	sh $CONSUMER_BIN
fi
