#!/bin/bash
set -e

if [[ -s pcf-bosh-creds/bosh-ca.pem ]]; then
  bosh -n --ca-cert pcf-bosh-creds/bosh-ca.pem target `cat pcf-bosh-creds/director_ip`
else
  bosh -n target `cat pcf-bosh-creds/director_ip`
fi

BOSH_USERNAME=$(cat pcf-bosh-creds/bosh-username)
BOSH_PASSWORD=$(cat pcf-bosh-creds/bosh-pass)

echo "Logging in to BOSH..."
bosh login <<EOF 1>/dev/null
$BOSH_USERNAME
$BOSH_PASSWORD
EOF

echo "Uploading Runtime Config..."
bosh update runtime-config pcf-prometheus-git/runtime.yml
