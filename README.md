# Prometheus BOSH release on Pivotal Cloud Foundry

This how-to has been tested on PCF 1.8. The manifest file is appropriate for cloud-config enabled environments.

## Upload the bosh release to your BOSH Director

```
bosh --ca-cert root_ca_certificate target <YOUR_BOSH_HOST>
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/prometheus-boshrelease
```
You can find root_ca_certificate file on the OpsManager VM in ```/var/tempest/workspaces/default/root_ca_certificate```.

## Create UAA clients
Key components of this BOSH release are [firehose_exporter](https://github.com/cloudfoundry-community/firehose_exporter) and [bosh_exporter](https://github.com/cloudfoundry-community/bosh_exporter) which retrieve the data (from CF firehose and BOSH director respectively) and present it in the Prometheus format. Each of those exporters require credentials to access the data source. IMPORTANT: these users have to be created in two different UAA instances. For the firehose credentials, you use the main UAA instance of a Cloud Foundry deployment (where you would normally create users/clients, such as those for any other nozzles). For bosh_exporter however, you need to use the UAA which is colocated with the BOSH Director.

### Create client for firehose_exporter
This process is explained here: https://github.com/cloudfoundry-community/firehose_exporter
```bash
uaac target https://<YOUR UAA URL> --skip-ssl-validation
uaac token client get <YOUR ADMIN CLIENT ID> -s <YOUR ADMIN CLIENT SECRET>
uaac client add prometheus-firehose \
  --name prometheus-firehose \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose
```
Edit name and secret values. You will need to put them in the manifest later.

### Create client for bosh_exporter
```bash
uaac target https://<YOUR BOSH URL>:8443 --skip-ssl-validation
uaac token owner get login -s UAA-LOGIN-CLIENT-PASSWORD
User name:  admin
Password:  UAA-ADMIN-CLIENT-PASSWORD
  uaac client add prometheus-bosh \
  --name prometheus-bosh \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities bosh.read \
  --scope bosh.read
```
Edit name and secret values. You will need to put them in the manifest later.

## Prepare your manifest based on the template from this repo
* Copy prometheus.yml from this repo to your working directory
* Edit CHANGE_ME placeholders (there are comments to help you find the right values)
* Edit cloud-config references accordingly (networks, azs, vm_type)

Once the manifest is ready, deploy:
```
bosh deployment prometheus.yml
bosh -n deploy
```

## Deploy node_exporter on all nodes
node_exporter is a core Prometheus exporter which provides detailed OS-level information. Using BOSH add-ons feature it's very easy to install node_exporter on all BOSH-provisioned VMs. Take the example runtime.yml (adjust the prometheus release version if needed) and run:
```
bosh update runtime-config runtime.yml
bosh -n deploy
```
Once that's done, any VM (re)created by BOSH will be running node_exporter. The manifest is already prepared to consume that data.

## Connect to Grafana
If the deployment was successful use ```bosh vms``` to find out the IP address of your nginx server. Then connect:
* https://NGINX:3000 to access Grafana (default credentials: admin/admin)
* https://NGINX:9090 to access Prometheus

There is a number of ready to use Dashboards that should install automatically. You can edit them in Grafana or create your own. They are coming from [prometheus-boshrelease/src](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/src).

## Grafana Plugins
UPDATE: this section was written when prometheus-boshrelease didn't include any Grafana plugins. Currently (v11) there are some plugins included so you likely don't need to do that. However, this info can still be helpful if you need to use a plugin which is not included. Make sure the folder (/var/vcap/store/grafana/plugins/) is configured in Grafana though.

If you want to install Grafana plugins you can do it the following way (this will install all officially supported plugins):
```
bosh ssh grafana
sudo -s
apt-get install jq git
cd /var/vcap/store/grafana/plugins/
wget https://raw.githubusercontent.com/grafana/grafana-plugin-repository/master/repo.json
for plugin in `jq .plugins[].url repo.json  | tr -d '"'`; do git clone $plugin; done
cd /var/vcap/bosh/bin/
./monit restart grafana
```
