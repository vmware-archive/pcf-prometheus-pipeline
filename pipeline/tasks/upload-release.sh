#!/bin/bash
set -e

function login_to_director() {
  CREDS=$1

  if [[ -s $CREDS/bosh-ca.pem ]]; then
    bosh -n --ca-cert $CREDS/bosh-ca.pem target `cat $CREDS/director_ip`
  else
    bosh -n target `cat $CREDS/director_ip`
  fi

  BOSH_USERNAME=$(cat $CREDS/bosh-username)
  BOSH_PASSWORD=$(cat $CREDS/bosh-pass)

  echo "Logging in to BOSH..."
  bosh login <<EOF 1>/dev/null
  $BOSH_USERNAME
  $BOSH_PASSWORD
EOF
}

login_to_director pcf-bosh-creds

echo "Uploading Prometheus Customizations Release..."
bosh -n upload release prometheus-custom-release/prometheus-custom-*.tgz

login_to_director deploy-bosh-creds

echo "Uploading Prometheus Release..."
bosh -n upload release prometheus-release/prometheus-*.tgz

echo "Uploading Node exporter Release..."
bosh -n upload release node-exporter-release/node-exporter-*.tgz
