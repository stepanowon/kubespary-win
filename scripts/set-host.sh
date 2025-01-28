#!/usr/bin/env bash

set -euo pipefail

cat << EOF > /etc/hosts
127.0.0.1			localhost

192.168.56.201  	vm1
192.168.56.202  	vm2
192.168.56.203  	vm3
EOF

cat /etc/hosts
