#!/bin/bash
set -e

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_cf_uaa

echo "Creating Prometheus UAA Client..."
uaac client add firehose_exporter \
  --name firehose_exporter \
  --secret ${uaa_clients_firehose_exporter_secret} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose || true #ignore errors

echo "Creating Prometheus CF Client..."
uaac client add cf_exporter \
  --name cf_exporter \
  --secret ${uaa_clients_cf_exporter_secret} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities cloud_controller.admin_read_only || true #ignore errors

login_to_bosh_uaa

echo "Creating Prometheus BOSH UAA Client ..."
uaac client add bosh_exporter \
  --name bosh_exporter \
  --secret ${uaa_bosh_exporter_client_secret} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities bosh.read \
  --scope bosh.read  || true #ignore errors
