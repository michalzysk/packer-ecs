#!/usr/bin/env bash
set -e

sudo sed -i -e '/^repo_update: /{h;s/: .*/: false/};${x;/^$/{s//repo_update: false/;H};x}' /etc/cloud/cloud.cfg
sudo sed -i -e '/^repo_upgrade: /{h;s/: .*/: false/};${x;/^$/{s//repo_upgrade: false/;H};x}' /etc/cloud/cloud.cfg
