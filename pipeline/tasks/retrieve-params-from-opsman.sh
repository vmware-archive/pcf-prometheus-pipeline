#!/bin/bash

mkdir params

system_domain=$($CURL --path=/api/v0/deployed/products/$cf_id/manifest | jq -r '.instance_groups[] | select (.name == "cloud_controller") | .jobs[] | select (.name == "cloud_controller_ng") | .properties.system_domain')
echo "system_domain: ${system_domain}" >> params/params.yml