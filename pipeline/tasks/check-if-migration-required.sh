#!/bin/bash

# required for `migration/*.yml` to find something
touch migration/empty.yml

# check if `prometheus` instance group exists
if grep -q '  name: prometheus$' < bosh-deployment/manifest.yml; then
  # add migration ops file if yes
  cat prometheus-release-git/manifests/operators/migrations/migrate_from_prometheus_1.yml > "${OPS_DIR}/migrate_from_prometheus_1.yml"
fi