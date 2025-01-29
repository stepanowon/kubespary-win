#!/usr/bin/env bash

set -euo pipefail

cp -r /vagrant /home/vagrant/
chown -R vagrant:vagrant /home/vagrant/vagrant
echo "### 샘플 예제 복사"