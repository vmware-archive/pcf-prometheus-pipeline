#!/bin/bash
set -e

if [[ -s deploy-bosh-creds/bosh-ca.pem ]]; then
  bosh -n --ca-cert deploy-bosh-creds/bosh-ca.pem target `cat deploy-bosh-creds/director_ip`
else
  bosh -n target `cat deploy-bosh-creds/director_ip`
fi

BOSH_USERNAME=$(cat deploy-bosh-creds/bosh-username)
BOSH_PASSWORD=$(cat deploy-bosh-creds/bosh-pass)

echo "Logging in to BOSH..."
bosh login <<EOF 1>/dev/null
$BOSH_USERNAME
$BOSH_PASSWORD
EOF

echo "Interpolating..."
eval "echo \"$(cat pcf-prometheus-git/pipeline/tasks/etc/local.yml)\"" > local.yml
bosh-cli interpolate pcf-prometheus-git/prometheus.yml -l local.yml > manifest.yml

echo "Deploying..."

bosh -n deployment manifest.yml

bosh -n deploy --no-redact
