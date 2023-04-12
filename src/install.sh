#! /bin/sh

set -eux
set -o pipefail

apk update

# install pg_dump
apk add postgresql14-client
apk add --no-cache mysql-client

# install gpg
apk add gnupg

apk add python3
apk add py3-pip  # separate package on edge only
pip3 install awscli

# install go-cron
apk add curl
curl -L https://github.com/vitalyredpill/go-cron/releases/download/v0.2.8/go-cron_0.2.8_linux_${TARGETARCH}.tar.gz -O
tar xvf go-cron_0.2.8_linux_${TARGETARCH}.tar.gz
rm go-cron_0.2.8_linux_${TARGETARCH}.tar.gz
mv go-cron /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron
apk del curl


# cleanup
rm -rf /var/cache/apk/*
