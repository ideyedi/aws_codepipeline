#!/bin/bash

set -e

sudo chown tomcat8:adm /home/ubuntu/tomcat8/bin/setenv.sh

sudo service tomcat85 restart || true
# sudo service nginx restart || true