#!/bin/bash
set -e

TMPDIR=${TMPDIR:-/tmp}
TMPFILE=$(mktemp "$TMPDIR/runtime-config.XXXXXX")

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_director pcf-bosh-creds

echo "Uploading Node exporter Release..."
bosh2 -n upload-release node-exporter-release/node-exporter-*.tgz

node_exporter_version=$(cat node-exporter-release/version)
bosh2 -n update-runtime-config --name=node_exporter pcf-prometheus-git/runtime.yml -v node_exporter_version=${node_exporter_version}
