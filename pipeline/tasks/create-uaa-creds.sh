#!/bin/bash
set -e

CURL="om --target https://${opsman_url} -k \
  --username ${pcf_opsman_admin_username} \
  --password ${pcf_opsman_admin_password} \
  curl"

echo "Getting UAA credentials..."
cf_id=$($CURL --path=/api/v0/deployed/products | jq -r '.[] | select(.type == "cf") | .guid')
uaa_creds=$($CURL --path=/api/v0/deployed/products/$cf_id/credentials/.uaa.admin_client_credentials)

uaa_client=$(echo $uaa_creds | jq -r .credential.value.identity)
uaa_secret=$(echo $uaa_creds | jq -r .credential.value.password)

pcf_sys_domain=$($CURL --path=/api/v0/deployed/products/$cf_id/manifest | jq -r '.instance_groups[] | select (.name == "cloud_controller") | .jobs[] | select (.name == "cloud_controller_ng") | .properties.system_domain')

echo "Creating Prometheus UAA Client..."
uaac target https://uaa.${pcf_sys_domain} --skip-ssl-validation
uaac token client get ${uaa_client} -s ${uaa_secret}
uaac client add firehose_exporter \
  --name firehose_exporter \
  --secret ${uaa_clients_firehose_exporter_secret} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose || true #ignore errors

echo "Creating Prometheus CF Client..."
uaac client add cf_exporter \
  --name cf_exporter \
  --secret ${uaa_clients_cf_exporter_secret} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities cloud_controller.admin_read_only || true

echo "Getting BOSH director IP..."
director_id=$($CURL --path=/api/v0/deployed/products | jq -r '.[] | select (.type == "p-bosh") | .guid'
director_ip=$($CURL --path=/api/v0/deployed/products/$director_id/static_ips | jq -r .[0].ips[0])

echo "Getting BOSH UAA creds..."
uaa_login_password=$($CURL --path=/api/v0/deployed/products/$director_id/credentials/.director.uaa_login_client_credentials | jq -r .credential.value.password)
uaa_admin_password=$($CURL --path=/api/v0/deployed/director/credentials/uaa_admin_user_credentials | jq -r .credential.value.password)

echo "Logging into BOSH UAA..."
uaac target https://$director_ip:8443 --skip-ssl-validation
uaac token owner get login -s $uaa_login_password<<EOF
admin
$uaa_admin_password
EOF

echo "Creating Prometheus BOSH UAA Client ..."
uaac client add bosh_exporter \
  --name bosh_exporter \
  --secret ${uaa_bosh_exporter_client_secret} \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities bosh.read \
  --scope bosh.read  || true #ignore errors
