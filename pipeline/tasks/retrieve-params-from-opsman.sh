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

$CURL --path=/api/v0/deployed/products/$cf_id/manifest > /tmp/cf-manifest.yml

system_domain=$(jq -r '.instance_groups[] | select (.name == "cloud_controller" or .name == "control") | .jobs[] | select (.name == "cloud_controller_ng") | .properties.system_domain' < /tmp/cf-manifest.yml)
echo "system_domain: ${system_domain}" >> ${PARAMS_FILE}

# In PCF 1.12 this property belongs to 'autoscaling' but in 2.0 to 'clock_global'
doppler_url=$(jq -r '.instance_groups[] | select(.name == "clock_global" or .name == "autoscaling") | .jobs[] | select (.name == "deploy-autoscaling") | .properties.doppler.host' < /tmp/cf-manifest.yml)
traffic_controller_external_port=${doppler_url/*:/}
echo "traffic_controller_external_port: ${traffic_controller_external_port}" >> ${PARAMS_FILE}

metron_deployment_name=$(jq -r '.instance_groups[] | select(.name == "diego_brain" or .name == "control") | .jobs[] | select(.name == "metron_agent") | select(.properties.metron_agent.deployment != null) | .properties.metron_agent.deployment' < /tmp/cf-manifest.yml)
echo "metron_deployment_name: ${metron_deployment_name}" >> ${PARAMS_FILE}

if [[ "${mysql_address}" != "null" ]]; then
  echo "mysql_address: ${mysql_address}" >> ${PARAMS_FILE}
  echo "mysql_username: ${mysql_username}" >> ${PARAMS_FILE}
  echo "mysql_password: ${mysql_password}" >> ${PARAMS_FILE}
  ln -s prometheus-release-git/manifests/operators/monitor-mysql.yml ${OPS_DIR}/monitor-mysql.yml
fi