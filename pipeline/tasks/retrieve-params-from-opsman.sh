#!/bin/bash

mkdir dynamic-params || true
PARAMS_FILE=dynamic-params/params.yml
rm -f ${PARAMS_FILE}

OPS_DIR=dynamic-params/ops
mkdir dynamic-params/ops || true
rm -f ${OPS_DIR}/*.yml
touch dynamic-params/ops/empty.yml

CURL="om --target https://${opsman_url} -k \
  --username ${pcf_opsman_admin_username} \
  --password ${pcf_opsman_admin_password} \
  curl"

cf_id=$($CURL --path=/api/v0/deployed/products | jq -r '.[] | select(.type == "cf") | .guid')
echo "cf_id: ${cf_id}" >> ${PARAMS_FILE}

$CURL --path=/api/v0/deployed/products/$cf_id/manifest > /tmp/cf-manifest.yml

system_domain=$(jq -r '.instance_groups[] | select (.name == "cloud_controller" or .name == "control") | .jobs[] | select (.name == "cloud_controller_ng") | .properties.system_domain' < /tmp/cf-manifest.yml)
echo "system_domain: ${system_domain}" >> ${PARAMS_FILE}

# Different versions of PCF define this property in different places
doppler_url=$(jq -r '.instance_groups[] | select(.name == "clock_global" or .name == "autoscaling" or .name == "control") | .jobs[] | select (.name == "deploy-autoscaling" or .name == "deploy-autoscaler") | .properties.doppler.host' < /tmp/cf-manifest.yml)
if [[ -z "$doppler_url" ]]; then
  doppler_url=$(jq -r '.instance_groups[] | select(.name == "clock_global" or .name == "autoscaling") | .jobs[] | select(.properties.doppler.host != null) | .properties.doppler.host' < /tmp/cf-manifest.yml)
fi
traffic_controller_external_port=${doppler_url/*:/}
echo "traffic_controller_external_port: ${traffic_controller_external_port}" >> ${PARAMS_FILE}

echo "metron_deployment_name: cf" >> ${PARAMS_FILE}

if [[ "${mysql_address}" != "null" ]]; then
  echo "mysql_address: ${mysql_address}" >> ${PARAMS_FILE}
  echo "mysql_username: ${mysql_username}" >> ${PARAMS_FILE}
  echo "mysql_password: ${mysql_password}" >> ${PARAMS_FILE}
  ln -s prometheus-release-git/manifests/operators/monitor-mysql.yml ${OPS_DIR}/monitor-mysql.yml
fi
