#!/usr/bin/env bash

set -euo pipefail

sed -i 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list.d/ubuntu.sources
sed -i 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list.d/ubuntu.sources

apt update
#apt upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

apt install -y python3 python3-pip
apt install -y git

ufw disable

apt install virtualbox-guest-additions-iso -y

echo virtualbox-ext-pack virtualbox-ext-pack/license select true | bconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-ext-pack