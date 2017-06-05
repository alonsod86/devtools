#!/bin/bash
CONFIG_FILE=$2

if [ -z "$1" ]
  then
    echo "Specify host's network interface and zookeepers bind address"
    echo "      ./configure.sh enp2s0 config.json"
    exit 1
fi

function loopOverHosts() {
	local service=$1
	local destination=$2
	local onlyPrint=$3
	count=0
	max=`jq -r ".services.$service[] | .ip" $CONFIG_FILE | wc -l`
	while [ $count -lt $max ]
	do
		host=`jq -r ".services.$service[$count] | .host" $CONFIG_FILE | sed 's/\"//g'`
		ip=`jq -r ".services.$service[$count] | .ip" $CONFIG_FILE | sed 's/\"//g'`
		
		if [ ! $onlyPrint ]; then
			echo "echo '$ip $host' >> /etc/hosts" >> $destination
		else
			echo "$ip    $host" | sed -e 's@$AGENT_IP@'"$AGENT_IP"'@'
		fi
		(( count++ ))
	done
}

# Restart minimesos cluster
echo "Tearing down minimesos cluster, please wait a few seconds..."
minimesos destroy
echo "Restarting minimesos cluster, please wait a few seconds..."
minimesos up

# Get current host ip and agent id
INNET_ADDR=`jq -cMSr '.deploy.eth' config.json`
HOST_IP=`ifconfig $1 | grep "$INNET_ADDR" | cut -d: -f2 | awk '{ print $1}'`
AGENT_ID=`docker ps | grep mesos-agent | awk '{ print $1}'`
AGENT_IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $AGENT_ID`
MASTER_ID=`docker ps | grep minimesos-zookeeper | awk '{ print $1}'`
MASTER_IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $MASTER_ID`
ZK_USERLAND=`jq -cMSr '.services.zk_userland' $CONFIG_FILE`

# install jq in the agent
if [ ! -f "jq" ]; then 
	wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
	mv jq-linux64 jq
fi
docker cp jq $AGENT_ID:/usr/bin

# Create a postinstall script with all the substitutions needed
echo "#!/bin/bash" > postinstall.sh
echo "echo '# zookeeper docker must' >> /etc/hosts" >> postinstall.sh
loopOverHosts ldap postinstall.sh
loopOverHosts gosec postinstall.sh
loopOverHosts kafka postinstall.sh

# Replace env variables inside temporal script
sed -e 's@$AGENT_IP@'"$AGENT_IP"'@' postinstall.sh > postinstall.sh.tmp
mv postinstall.sh.tmp postinstall.sh

# ensure that the agent sees the zk on the remote host
echo "echo '$HOST_IP $ZK_USERLAND' >> /etc/hosts" >> postinstall.sh
echo "echo '$MASTER_IP master.mesos' >> /etc/hosts" >> postinstall.sh
echo "chmod +x /usr/bin/jq" >> postinstall.sh
chmod +x postinstall.sh

# Copy postinstall script to docker agent
docker cp postinstall.sh $AGENT_ID:/tmp
docker exec -it $AGENT_ID sh /tmp/postinstall.sh

# Cleanup
rm postinstall.sh
echo "Please, add the following to your /etc/hosts"
loopOverHosts kafka "" true

