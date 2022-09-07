#!/bin/bash

set -e

## append cloudwatch agent log config
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a append-config -m ec2 -s -c file:/home/ubuntu/app.conf.json

# rearrange instance alarm
cd /home/ubuntu
# if [[ $DEPLOYMENT_GROUP_NAME = *"Live"* ]]; then
#     curl -X POST -H "Content-Type: application/json" -d @./alarm.json https://jen7wdhaqj.execute-api.ap-northeast-2.amazonaws.com/v1/alarm
# fi
rm ./alarm.json
