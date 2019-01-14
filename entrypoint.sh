#!/usr/bin/env bash

USER_ID=${LOCAL_UID:-9001}
GROUP_ID=${LOCAL_GID:-9001}

echo "Starting SSH Server"
/usr/sbin/sshd

echo "Starting with UID: $USER_ID, GID: $GROUP_ID"
usermod -u ${USER_ID} user
groupmod -g ${GROUP_ID} user
export HOME=/home/user

exec /usr/sbin/gosu user "$@"
