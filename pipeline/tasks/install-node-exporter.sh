#!/bin/bash
set -e

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/source common.sh

login_to_director pcf-bosh-creds

echo "Uploading Runtime Config..."
bosh update-runtime-config pcf-prometheus-git/runtime.yml
