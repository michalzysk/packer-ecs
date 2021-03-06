#!/usr/bin/env bash
set -e

# Configure ECS agent
echo "ECS_CLUSTER=${ECS_CLUSTER}" >> /etc/ecs/ecs.config

if [ -n $PROXY_URL ]
then
  echo export HTTPS_PROXY=$PROXY_URL >> /etc/sysconfig/docker
  echo HTTPS_PROXY=$PROXY_URL >> /etc/ecs/ecs.config
  echo NO_PROXY=169.254.169.254,169.254.170.2,/var/run/docker.sock >> /etc/ecs/ecs.config
  echo HTTP_PROXY=$PROXY_URL >> /etc/awslogs/proxy.conf
  echo HTTPS_PROXY=$PROXY_URL >> /etc/awslogs/proxy.conf
  echo NO_PROXY=169.254.169.254 >> /etc/awslogs/proxy.conf
fi

if [ $DOCKER_NETWORK_MODE = "host" ]
then
  sudo sed -i -e "s|^\(OPTIONS=\".*\)\"$|\1 --bridge=none --ip-forward=false --ip-masq=false --iptables=false\"|" \
    /etc/sysconfig/docker
fi

sudo tee /ect/awslogs/awscli << EOF > /dev/null
[plugins]
cwlogs = cwlogs
[default]
region = ${AWS_DEFAULT_REGION}
EOF

# write AWS logs config
sudo tee /etc/awslogs/awslogs.conf << EOF > /dev/null
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_group_name = ${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/dmesg
log_stream_name = {instance_id}

[/var/log/messages]
file = /var/log/messages
log_group_name = ${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/messages
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S

[/var/log/docker]
file = /var/log/docker
log_group_name = ${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/docker
log_stream_name = {instance_id}
datetime_format = %Y-%m-%dT%H:%M:%S.%f

[/var/log/ecs/ecs-init.log]
file = /var/log/ecs/ecs-init.log*
log_group_name = ${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/ecs/ecs-init
log_stream_name = {instance_id}
datetime_format = %Y-%m-%dT%H:%M:%S
time_zone = UTC

[/var/log/ecs/ecs-agent.log]
file = /var/log/ecs/ecs-agent.log*
log_group_name = ${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/ecs/ecs-agent
log_stream_name = {instance_id}
datetime_format = %Y-%m-%dT%H:%M:%S
time_zone = UTC
EOF

sudo service awslogs start
sudo chkconfig docker on
sudo service docker start
sudo start ecs

if [[ -z ${ECS_CLUSTER} ]]
then
  echo "Skipping ECS agent check as ECS_CLUSTER variable is not defined"
  exit 0
fi

echo "Checking ECS agent is joined to ${ECS_CLUSTER}"
until [[ "$(curl --fail --silent http://localhost:51678/v1/metadata | jq '.Cluster // empty' -r -e)" == ${ECS_CLUSTER} ]]
  do printf '.'
  sleep 5
done
echo "ECS agent successfully joined to ${ECS_CLUSTER}"
