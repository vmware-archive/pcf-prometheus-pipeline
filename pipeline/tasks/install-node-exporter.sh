#!/bin/bash
set -e

TMPDIR=${TMPDIR:-/tmp}
runtime-config-file=$(mktemp "$TMPDIR/runtime-config.XXXXXX")

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_director pcf-bosh-creds

# Check if existing runtime config is empty
# Unfortunately bosh file.yml -o opsfile.yml fails if file.yml is empty
# therefore we check if it is and apply runtime config appropriately
bosh2 runtime-config > "${runtime-config-file}"
lines=$(wc -l < "${runtime-config-file}" | xargs)
echo "Uploading Runtime Config..."
if [[ $lines -eq 1 ]]; then
    bosh2 update-runtime-config pcf-prometheus-git/runtime.yml
else
    bosh2 update-rntime-config "${runtime-config-file}" -o pcf-prometheus-git/runtime-ops.yml
fi