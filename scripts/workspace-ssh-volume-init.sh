#!/bin/bash
set -euo pipefail

# SSH 挂载卷首次为空或非 admin 属主时会无法免密登录；仅此固定权限与空 authorized_keys。
install -d -m 0700 -o admin -g admin /home/admin/.ssh
if [ ! -f /home/admin/.ssh/authorized_keys ]; then
  install -m 0600 -o admin -g admin /dev/null /home/admin/.ssh/authorized_keys
else
  chown admin:admin /home/admin/.ssh/authorized_keys
  chmod 0600 /home/admin/.ssh/authorized_keys
fi
