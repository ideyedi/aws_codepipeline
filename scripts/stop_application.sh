#!/bin/bash

set -e

# disable previous deployments
sudo systemctl stop monitor-api.service || true
sudo systemctl disable monitor-api.service || true

sudo service tomcat85 stop || true
sudo service nginx stop || true
