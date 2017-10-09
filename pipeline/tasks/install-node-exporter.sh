#!/bin/bash
set -e

TMPDIR=${TMPDIR:-/tmp}
TMPFILE=$(mktemp "$TMPDIR/runtime-config.XXXXXX")

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

login_to_director pcf-bosh-creds

echo "Uploading Node exporter Release..."
bosh2 -n upload-release node-exporter-release/node-exporter-*.tgz

# Check if existing runtime config is empty
# Unfortunately bosh file.yml -o opsfile.yml fails if file.yml is empty
# therefore we check if it is and apply runtime config appropriately
bosh2 runtime-config > "${TMPFILE}"
lines=$(wc -l < "${TMPFILE}" | xargs)
echo "Uploading Runtime Config..."
if [[ $lines -eq 1 ]]; then
    bosh2 -n update-runtime-config pcf-prometheus-git/runtime.yml
else
    if ! grep -q "release: node-exporter" "${TMPFILE}"; then
        bosh2 -n update-runtime-config "${TMPFILE}" -o pcf-prometheus-git/runtime-ops.yml
    fi
fi