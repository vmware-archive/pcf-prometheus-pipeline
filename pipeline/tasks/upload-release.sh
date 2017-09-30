#!/bin/bash
set -e

source common.sh

login_to_director pcf-bosh-creds

echo "Uploading Node exporter Release..."
bosh -n upload-release node-exporter-release/node-exporter-*.tgz
