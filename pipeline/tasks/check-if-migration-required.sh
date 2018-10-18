#!/bin/bash
set -e

root_dir=$(cd "$(dirname "$0")/.." && pwd)

source ${root_dir}/tasks/common.sh

# required for `migration/*.yml` to find something
touch migration/empty.yml

login_to_director pcf-bosh-creds

set +e

# check if a previous deployment exists
bosh -n deployments | grep -q "^${deployment_name} "

if [ $? != 0 ]; then
  exit 0
fi

# check if there is a job called `prometheus`
# if yes then it's Prometheus v1 and we apply migration ops file
bosh -n -d ${deployment_name} vms | grep -q 'prometheus/'

if [ $? != 0 ]; then
  exit 0
fi

set -e

# Prometheus v1 job exists; add migration ops files
cp prometheus-release-git/manifests/operators/migrations/migrate_from_prometheus_1.yml migration/
cp pcf-prometheus-pipeline/pcf-cloud-config-ops-migration.yml migration/