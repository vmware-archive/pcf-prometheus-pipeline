#!/bin/bash

function login_to_director() {
	CREDS=${1}
	DIRECTOR_FOR_DEPLOYMENT=${2}

	if [[ ${DIRECTOR_FOR_DEPLOYMENT} == "external_bosh" ]]; then
		source "$CREDS/external_bosh.sh"
	elif [[ -f $CREDS/bosh2_commandline_credentials ]]; then
		source "$CREDS/bosh2_commandline_credentials"
	else
		export BOSH_CA_CERT=$(cat "$CREDS/bosh-ca.pem")
		export BOSH_ENVIRONMENT="$(cat "$CREDS/director_ip")"
		export BOSH_CLIENT=$(cat "$CREDS/bosh-username")
		export BOSH_CLIENT_SECRET=$(cat "$CREDS/bosh-pass")
	fi
}

function login_to_cf_uaa() {
	CURL="om --target https://${opsman_url} -k \
	--username ${pcf_opsman_admin_username} \
	--password ${pcf_opsman_admin_password} \
	curl"

	echo "Getting UAA credentials..."
	cf_id=$($CURL --path=/api/v0/deployed/products | jq -r '.[] | select(.type == "cf") | .guid')
	uaa_creds=$($CURL --path=/api/v0/deployed/products/$cf_id/credentials/.uaa.admin_client_credentials)

	uaa_client=$(echo $uaa_creds | jq -r .credential.value.identity)
	uaa_secret=$(echo $uaa_creds | jq -r .credential.value.password)

	system_domain=$($CURL --path=/api/v0/deployed/products/$cf_id/manifest | jq -r '.instance_groups[] | select (.name == "cloud_controller" or .name == "control") | .jobs[] | select (.name == "cloud_controller_ng") | .properties.system_domain')

	uaac target https://uaa.${system_domain} --skip-ssl-validation
	uaac token client get ${uaa_client} -s ${uaa_secret}
}

function login_to_bosh_uaa() {
	echo "Getting BOSH director IP..."
	director_id=$($CURL --path=/api/v0/deployed/products | jq -r '.[] | select (.type == "p-bosh") | .guid')
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
}