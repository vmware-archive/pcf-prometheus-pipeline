#!/bin/bash
set -e

source common.sh

login_to_director pcf-bosh-creds

echo "Uploading Runtime Config..."
bosh update-runtime-config pcf-prometheus-git/runtime.yml
