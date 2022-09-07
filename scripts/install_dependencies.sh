#!/bin/bash

set -e

# apt repository
cd /home/ubuntu
sudo cp /etc/apt/sources.list ./sources.list
sudo perl -pi -e "s/security.ubuntu.com\/ubuntu/aptget.wonders.internal\/ubuntu/g" ./sources.list
sudo perl -pi -e "s/ap-northeast-2.ec2.archive.ubuntu.com\/ubuntu/aptget.wonders.internal\/ubuntu/g" ./sources.list
sudo cp ./sources.list /etc/apt/sources.list
sudo apt update

# Install awscli v2 and uninstall awscli v1
if [[ ! -f "/usr/local/bin/aws" ]]; then
    cd /home/ubuntu
    sudo apt -y remove awscli
    sudo apt -y install unzip
    rm -rf ./aws
    rm -f ./awscliv2.zip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    source .bashrc
    aws --version
fi

sudo apt update
sudo apt -y install openjdk-8-jdk
sudo rm -f /usr/lib/jvm/default-java
sudo ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/default-java

# Mornitoring Services
if [[ $DEPLOYMENT_GROUP_NAME = *"Live"* || $DEPLOYMENT_GROUP_NAME = *"Pre"* ]]; then
    sudo service filebeat restart || true
    sudo service packetbeat restart || true
    sudo service auditbeat restart || true
else
    sudo service filebeat stop || true
    sudo service packetbeat stop || true
    sudo service auditbeat stop || true
fi

if [[ -f  "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl" ]]; then
    echo "cloudwatch agent already installed..."
else
    cd /home/ubuntu
    
    echo "Downloading cloudwatch agent"
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    
    echo "Installing cloudwatch agent"
    sudo apt install ./amazon-cloudwatch-agent.deb

    echo "Fetch config from parameter store"
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatchAgent-Ec2-linux
fi

DOMAIN="localhost"

## Install tomcat8
#if [[ $(service --status-all | grep tomcat8) == "" ]]; then
#    sudo apt -y install tomcat8
#fi
#sudo chmod 755 /var/lib/tomcat8/webapps
# Install Tomcat85
if ! id "tomcat8" > /dev/null 2>&1; then
    sudo adduser --home /home/tomcat8 --shell /usr/sbin/nologin --gecos "" --disabled-password --disabled-login tomcat8
fi
if [[ ! -f "/etc/systemd/system/tomcat85.service" ]]; then
    cd /opt
    sudo rm -rf ./apache-tomcat-8*

    TOMCAT_VER="8.5.72"
    sudo aws s3 cp s3://wmp-system-admin/apache-tomcat/apache-tomcat-${TOMCAT_VER}.tar.gz ./ --region ap-northeast-2
    sudo tar xvfz apache-tomcat-${TOMCAT_VER}.tar.gz
    sudo ln -s /opt/apache-tomcat-${TOMCAT_VER} /home/ubuntu/tomcat8
    sudo chown -R tomcat8:adm /opt/apache-tomcat-${TOMCAT_VER}
    cd /home/ubuntu
    cat <<EOF >>./tomcat85.service
[Unit]
Description=Apache Tomcat8.5
After=syslog.target network.target
[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/default-java
Environment=CATALINA_PID=/home/ubuntu/tomcat8/temp/tomcat.pid
Environment=CATALINA_HOME=/home/ubuntu/tomcat8
Environment=CATALINA_BASE=/home/ubuntu/tomcat8
Environment='CATALINA_OPTS=-server -XX:+UseG1GC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'
WorkingDirectory=/home/ubuntu/tomcat8
ExecStart=/home/ubuntu/tomcat8/bin/startup.sh
ExecStop=/home/ubuntu/tomcat8/bin/shutdown.sh
User=tomcat8
Group=tomcat8
UMask=0007
RestartSec=10
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    sudo cp ./tomcat85.service /etc/systemd/system/
    rm ./tomcat85.service
    sudo systemctl daemon-reload
    
    sudo rm -rf /home/ubuntu/tomcat8/webapps/*
    sudo rm -rf /home/ubuntu/tomcat8/logs
    sudo mkdir -p /var/log/tomcat8
    sudo chown -R tomcat8:adm /var/log/tomcat8
    sudo ln -s /var/log/tomcat8 /home/ubuntu/tomcat8/logs
fi

if [ -f "/home/ubuntu/tomcat8/webapps/ROOT.war" ]; then
    sudo rm -f /home/ubuntu/tomcat8/webapps/ROOT.war
fi

if [ -d "/home/ubuntu/tomcat8/webapps/ROOT" ]; then
    sudo rm -rf /home/ubuntu/tomcat8/webapps/ROOT
fi

if [ -f "/home/ubuntu/tomcat8/conf/server.xml" ]; then
    sudo rm -f /home/ubuntu/tomcat8/conf/server.xml
fi

sudo rm -f /home/ubuntu/tomcat8/webapps/ROOT.war
sudo rm -rf /home/ubuntu/tomcat8/webapps/ROOT
sudo rm -f /home/ubuntu/tomcat8/conf/server.xml
# sudo rm -f /home/ubuntu/tomcat8/conf/web.xml
sudo rm -f /home/ubuntu/tomcat8/bin/setenv.sh

# ENV 환경 변수 지정
if [[ $DEPLOYMENT_GROUP_NAME = *"Live"* ]]; then
    ENV="prod"
    PINPOINT_DEPLOY=""
    PINPOINT_URL="pinpoint-collector.wemakeprice.work"
    PINPOINT_SAMPLING_RATE="10"
    PINPOINT_LOG_LEVEL="ERROR"
elif [[ $DEPLOYMENT_GROUP_NAME = *"Pre"* ]]; then
    ENV="pre"
    PINPOINT_DEPLOY=".pre"
    PINPOINT_URL="pinpoint-collector.wemake-stg.com"
    PINPOINT_SAMPLING_RATE="1"
    PINPOINT_LOG_LEVEL="WARN"
elif [[ $DEPLOYMENT_GROUP_NAME = *"Tst"* ]]; then
    ENV="tst"
    PINPOINT_DEPLOY=".pre"
    PINPOINT_URL="pinpoint-collector.wemake-qa.com"
    PINPOINT_SAMPLING_RATE="1"
    PINPOINT_LOG_LEVEL="WARN"
elif [[ $DEPLOYMENT_GROUP_NAME = *"Stg"* ]]; then
    ENV="stg"
    PINPOINT_DEPLOY=""
    PINPOINT_URL="pinpoint-collector.wemake-qa.com"
    PINPOINT_SAMPLING_RATE="1"
    PINPOINT_LOG_LEVEL="WARN"
else
    ENV="dev"
    PINPOINT_DEPLOY=".dev"
    PINPOINT_URL="pinpoint-collector.wemake-dev.com"
    PINPOINT_SAMPLING_RATE="1"
    PINPOINT_LOG_LEVEL="WARN"
fi

ISID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

#echo $ENV
if [[ -f '/opt/codedeploy-agent/deployment-root/'$DEPLOYMENT_GROUP_ID'/'$DEPLOYMENT_ID'/deployment-archive/setenv.sh' ]]; then
    sudo perl -pi -e 's/#param#/'"$ENV"'/g' /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/setenv.sh
    sudo perl -pi -e "s/#isid#/$ISID/g" /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/setenv.sh
    # sudo perl -pi -e "s/#pinpoint-url#/$PINPOINT_URL/g" /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/pinpoint.config
    # sudo perl -pi -e "s/#pinpoint-sampling-rate#/$PINPOINT_SAMPLING_RATE/g" /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/pinpoint.config
    # sudo perl -pi -e "s/#pinpoint-log-level#/$PINPOINT_LOG_LEVEL/g" /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/log4j2.xml
fi

# nginx
# if [[ $(sudo service --status-all | grep -E "nginx") == "" ]]; then
#     sudo apt -y install nginx
# fi

# DOMAIN="localhost"

# sudo perl -pi -e "s/#domain#/$DOMAIN/g" /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/template_default.conf

# sudo rm -f /etc/nginx/conf.d/*
# sudo cp -f /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/template_default.conf /etc/nginx/conf.d/default.conf
# sudo cp -f /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/template_proxy /etc/nginx/conf.d/proxy
# sudo cp -f /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/template_nginx.conf /etc/nginx/nginx.conf

# Install pinpoint agent
sudo rm -f /home/ubuntu/pinpoint-agent*.tar.gz
sudo rm -rf /home/ubuntu/pinpoint-agent
cd /home/ubuntu/
mkdir -p pinpoint-agent
# sudo wget https://github.com/pinpoint-apm/pinpoint/releases/download/v2.3.3/pinpoint-agent-2.3.3.tar.gz
aws s3 cp s3://wmp-system-admin/pinpoint-agent/pinpoint-agent-2.3.3.tar.gz .
tar xvfz pinpoint-agent*.tar.gz -C /home/ubuntu/pinpoint-agent --strip-components=1
sudo chown -R tomcat8:tomcat8 /home/ubuntu/pinpoint-agent

# pinpoint.config 설정 치환
sudo sed -i "/profiler.transport.grpc.collector.ip=/ c\profiler.transport.grpc.collector.ip=$PINPOINT_URL" /home/ubuntu/pinpoint-agent/profiles/release/pinpoint.config
sudo sed -i "/profiler.collector.ip=/ c\profiler.collector.ip=$PINPOINT_URL" /home/ubuntu/pinpoint-agent/profiles/release/pinpoint.config
sudo sed -i "/profiler.sampling.rate=/ c\profiler.sampling.rate=$PINPOINT_SAMPLING_RATE" /home/ubuntu/pinpoint-agent/profiles/release/pinpoint.config
 
# Pinpoint Log Level 치환
sudo sed -i 's/level=\"INFO\" additivity''/level=\"'$PINPOINT_LOG_LEVEL'\" additivity/g' /home/ubuntu/pinpoint-agent/profiles/release/log4j2.xml
sudo sed -i 's/Root level=\"INFO\"''/Root level=\"'$PINPOINT_LOG_LEVEL'\"/g' /home/ubuntu/pinpoint-agent/profiles/release/log4j2.xml

# Time Zone
sudo timedatectl set-timezone Asia/Seoul

# hostname
ISID=$(curl 169.254.169.254/latest/meta-data/instance-id)
IPv4=$(curl 169.254.169.254/latest/meta-data/local-ipv4)
IP=${IPv4//./-}
HOSTNAME=$(aws ec2 describe-tags --region ap-northeast-2 --filters "Name=resource-id,Values=$ISID" "Name=key,Values=Name" | python3 -c "import sys,json; print(json.load(sys.stdin)['Tags'][0]['Value'])")
HOSTNAMEIP=$(echo $HOSTNAME-$IP)
echo "host name ... "$HOSTNAMEIP
sudo hostnamectl set-hostname $HOSTNAMEIP
cat <<EOF >./hosts
127.0.0.1 localhost
127.0.0.1 $HOSTNAMEIP
EOF
sudo perl -pi -e 's/^\n//' ./hosts
sudo cp ./hosts /etc/hosts
rm ./hosts

if [[ ! -f /etc/logrotate.d/tomcat8 ]]; then
    cd /home/ubuntu
    sudo rm -f /etc/logrotate.d/tomcat8
    touch ./logrtomcat8
    sudo echo "/var/log/tomcat8/catalina.out {
  copytruncate
  daily
  rotate 5
  compress
  dateext
  dateyesterday
  missingok
  create 640 tomcat8 adm
    }" >> ./logrtomcat8
    sudo cp ./logrtomcat8 /etc/logrotate.d/tomcat8
fi

# create alarm api payload
cat <<EOF >./alarm.json
{
    "instanceid": "$ISID",
    "instancetagname": "$HOSTNAME",
    "hostnameip": "$HOSTNAMEIP"
}
EOF

sudo service networking restart
sudo service rsyslog restart