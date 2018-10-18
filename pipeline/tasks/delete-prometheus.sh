#!/bin/bash
set -e

TMPDIR=${TMPDIR:-/tmp}
TMPFILE=$(mktemp "$TMPDIR/runtime-config.XXXXXX")

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_director pcf-bosh-creds ${director_for_deployment}

echo "Deleting ${deployment} deployment"
bosh delete-deployment -d ${deployment} --non-interactive

login_to_cf_uaa

echo "Deleting Prometheus UAA Client..."
uaac client delete firehose_exporter

echo "Deleting Prometheus CF Client..."
uaac client delete cf_exporter

login_to_bosh_uaa

echo "Deleting Prometheus BOSH UAA Client ..."
uaac client delete bosh_exporter