#!/usr/bin/env bash

set -euo pipefail

# vagrant 사용자 패스워드 변경
echo "vagrant:asdf" | chpasswd vagrant
echo "### vagrant 사용자 암호 변경 완료"