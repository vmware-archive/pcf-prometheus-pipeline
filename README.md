# Prometheus BOSH release on Pivotal Cloud Foundry

This how-to has been tested on PCF 1.8. The manifest file is appropriate for cloud-config enabled environments.

## Upload the bosh release to your BOSH Director

```
bosh --ca-cert root_ca_certificate target <YOUR_BOSH_HOST>
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/prometheus-boshrelease
```
You can find root_ca_certificate file on the OpsManager VM in

## Create UAA clients
Key components of this BOSH release are [firehose_exporter](https://github.com/cloudfoundry-community/firehose_exporter) and [bosh_exporter](https://github.com/cloudfoundry-community/bosh_exporter) which retrieve the data (from CF firehose and BOSH director respectively) and present it in the Prometheus format. Each of those exporters require credentials to access the data source. IMPORTANT: these users have to be created in two different UAA instances. For the firehose credentials, you use the main UAA instance of a Cloud Foundry deployment (where you would normally create users/clients, such as those for any other nozzles). For bosh_exporter however, you need to use the UAA which is colocated with the BOSH Director.

### Create client for firehose_exporter
This process is explained here: https://github.com/cloudfoundry-community/firehose_exporter
```bash
uaac target https://<YOUR UAA URL> --skip-ssl-validation
uaac token owner get login admin
Client secret:  OpsManager -> Director -> Credentials -> Uaa Login Client Credentials
Password:  OpsManager -> Director -> Credentials -> Uaa Admin User Credentials
uaac client add prometheus-bosh \
  --name prometheus-bosh \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities bosh.admin \
  --scope bosh.admin
```
Edit name and secret values. You will need to put them in the manifest later.

### Create client for bosh_exporter
```bash
uaac target https://<YOUR BOSH URL>:8443 --skip-ssl-validation
uaac token client get <YOUR ADMIN CLIENT ID> -s <YOUR ADMIN CLIENT SECRET>
uaac client add prometheus-firehose \
  --name prometheus-firehose \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose
```
Edit name and secret values. You will need to put them in the manifest later.

##
## Prepare your manifest based on the template from this repo
* Copy prometheus.yml from this repo to your working directory
* Edit CHANGE_ME placeholders (there are comments to help you find the right values)
* Edit cloud-config references accordingly (networks, azs, vm_type)

Once the manifest is ready, deploy:
```
bosh deployment prometheus.yml
bosh -n deploy
```

## Connect to Grafana
If the deployment was successful use ```bosh vms``` to find out the IP address of your nginx server. Then connect:
* https://<YOUR NGINX SERVER>:3000 to access Grafana (default credentials: admin/admin)
* https://<YOUR NGINX SERVER>:9090 to access Prometheus

There is a number of ready to use Dashboards that you can import from [prometheus-boshrelease/src](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/src)
