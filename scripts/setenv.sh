# Default
APPLICATION_NAME=monitor-api
JAVA_OPTS="-Dspring.profiles.active=#param# -server -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true "
# Memory Size
ISTYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type)
# instanceType t3.medium 4GB, t3.large 8GB, t3.xlarge 16GB
if [ $ISTYPE = 't3.xlarge' ]; then
    JAVA_OPTS="${JAVA_OPTS} -Xms8192M -Xmx8192M -XX:NewSize=512m -XX:MaxNewSize=512m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"
elif [ $ISTYPE = 't3.large' ]; then
    JAVA_OPTS="${JAVA_OPTS} -Xms4096M -Xmx4096M -XX:NewSize=512m -XX:MaxNewSize=512m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"
else
    JAVA_OPTS="${JAVA_OPTS} -Xms2048M -Xmx2048M -XX:NewSize=256m -XX:MaxNewSize=256m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"
fi
# GC option
JAVA_OPTS="${JAVA_OPTS} -XX:+DisableExplicitGC -verbose:gc -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:/var/log/monitor-api-gc.log -XX:+UseG1GC -XX:-UseConcMarkSweepGC"
# heap dump
JAVA_OPTS="${JAVA_OPTS} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/home/ubuntu/tomcat8/logs -XX:ErrorFile=/home/ubuntu/tomcat8/hs_err_pid%p.log"
# pinpoint
JAVA_OPTS="${JAVA_OPTS} -javaagent:/home/ubuntu/pinpoint-agent/pinpoint-bootstrap-2.3.3.jar -Dpinpoint.agentId=#isid# -Dpinpoint.applicationName=${APPLICATION_NAME} -Dpinpoint.profiler.profiles.active=release"
