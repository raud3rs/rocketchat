#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

if [[ -z "$1" ]]; then
    echo "usage $0 [start|post-start]"
    exit 1
fi

. $SNAP_COMMON/config/rocketchat.env

case $1 in
pre-start)
    timeout 300 /bin/bash -c 'until echo > /dev/tcp/localhost/'$MONGODB_PORT'; do sleep 1; done'
    ;;
start)
    exec ${DIR}/nodejs/bin/node ${DIR}/bundle/main.js
    ;;
*)
    echo "not valid command"
    exit 1
    ;;
esac