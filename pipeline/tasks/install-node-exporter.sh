#!/bin/bash
set -e

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_director pcf-bosh-creds

echo "Uploading Node exporter Release..."
bosh -n upload-release node-exporter-release/node-exporter-*.tgz

node_exporter_version=$(cat node-exporter-release/version)
bosh -n update-runtime-config --name=node_exporter pcf-prometheus-pipeline/runtime.yml -v node_exporter_version=${node_exporter_version}
