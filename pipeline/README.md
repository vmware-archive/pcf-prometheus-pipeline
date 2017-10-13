## Pipeline for deploying Prometheus to PCF

This pipeline sets up a Prometheus monitoring environment for PCF.

It can target an ops manager BOSH director or a standalone bosh director to monitor/deploy to.

## Jobs

- **Upload Release**

  Uploads the Prometheus BOSH releases to the target director.

- **Create UAA Creds**

  Creates UAA Credentials both in Cloud Foundry and BOSH (requires Ops Manager for now)

- **Deploy**

  Performs the deployment

## Parameters:

Information about the PCF foundation you want to monitor:
  - `opsman_url`: OpsManager URL
  - `pcf_opsman_admin_username`: OpsManager admin username
  - `pcf_opsman_admin_password`: OpsManager admin password

BOSH Director to deploy Prometheus to. For production use cases it is recommended to deploy Prometheus to a dedicated BOSH Director (not the one deployed by OpsManager). Therefore you need to provide these parameters separately. If you want to just test Prometheus, you can provide the details of your OpsManager-managed Director - it will work as well.

  - `bosh_username`: BOSH Director username
  - `bosh_password`: BOSH Director password
  - `director_ip`: BOSH Director IP
  - `bosh_ca`: BOSH CA certificate (if any)
  - `deploy_azs`: Deployment AZs (Array)
  - `deploy_network`: Deployment Network
  - `deploy_vm_password`: SHA of the VM Password
  - `deploy_nginx_ip`: IP for front end server

Other parameters:
  - `github_token`: A github token
  - `uaa_bosh_exporter_client_secret`: Secret for the bosh_exporter BOSH UAA client
  - `uaa_clients_firehose_exporter_secret`: Secret for the firehost_exporter CF UAA client
  - `uaa_clients_cf_exporter_secret`: Secret for the cf_exporter CF UAA client


- `bosh_creds_source`: Source of BOSH credentials (`opsman` or `manual`)

