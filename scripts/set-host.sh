#!/usr/bin/env bash

set -euo pipefail

cat << EOF > /etc/hosts
127.0.0.1			localhost

192.168.56.201  	k8s-master
192.168.56.202  	k8s-node1
192.168.56.203  	k8s-node2
EOF

cat /etc/hosts
