#!/usr/bin/env bash
set -e

echo "### Performing final clean-up tasks ###"
sudo service docker stop
sudo chkconfig docker off
sudo rm -rf /var/log/docker /var/log/ecs/*

sudo rm -Rf /var/run/docker.sock

# remove docker network database
sudo rm -rf /var/lib/docker/network

# remove docker0 interface if it has been created
sudo ip link del docker0 || true
