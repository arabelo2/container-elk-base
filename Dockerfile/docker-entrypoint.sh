#!/bin/bash
set -e

# Files created by Elasticsearch should always be group writable too
umask 0002

# Allow user specify custom CMD to run /bin/bash to check the image
if [[ "$1" != "eswrapper" ]]; then
  exec "$@"
fi

if [[ "$(id -u)" == "0" ]]; then
    echo "Running as root, and droping to specified UID to run command"
    exec chroot --userspec=1000 / /usr/local/bin/elasticsearch-docker.sh "eswrapper" \
    & \
    exec chroot --userspec=1001 / /usr/local/bin/kibana-docker.sh \
    & \
    exec chroot --userspec=1002 / /usr/local/bin/logstash-docker.sh
else
    echo "Either we are running in Openshift with random uid and are a member of the root group or with a custom --user"
    exec /usr/local/bin/elasticsearch-docker.sh "eswrapper" \
    & \
    exec /usr/local/bin/kibana-docker.sh \
    & \
    exec /usr/local/bin/logstash-docker.sh
fi
