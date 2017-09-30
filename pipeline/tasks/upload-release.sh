#!/bin/bash
set -e

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_director pcf-bosh-creds

echo "Uploading Node exporter Release..."
bosh-cli -n upload-release node-exporter-release/node-exporter-*.tgz
