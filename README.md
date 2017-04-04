# Prometheus BOSH release on Pivotal Cloud Foundry

This how-to has been tested on PCF 1.8. The manifest file is appropriate for cloud-config enabled environments.

The manifest example is split into the main part which should not require any customization (at least initially) and the local configuration which has to be adjusted. To merge those files we are using the new [BOSH CLI (beta)](https://github.com/cloudfoundry/bosh-cli). Documentation is available [here](http://bosh.io/docs/cli-v2.html). It is perfectly possible to use this CLI for all other steps involving a BOSH CLI.

# How it works
This is a high-level overview of monitoring Cloud Foundry with Prometheus
![logical diagram](https://github.com/mkuratczyk/prometheus-on-PCF/blob/master/docs/logical-diagram.png)

Notes:
* since Prometheus uses a pull mechanism, connections are initiated by Prometheus
* if you deploy the bosh release using the provided manifest, exporters are colocated with Prometheus (except node_exporter which is a BOSH add-on and runs on all VMs)
* prometheus-boshrelease includes a number of other exporters you can use which are not included in the example
* you don't really need the nginx job/VM if you just want to kick the tires but you'll probably need it in a serious deployment to terminate SSL and provide authentication for Prometheus (Grafana requires authentication anyway)
* in a production environment you should probably put firehose_exporter on a separate VM to scale it out independently

## Upload the bosh releases to your BOSH Director

```
bosh --ca-cert root_ca_certificate target <YOUR_BOSH_HOST>
bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/prometheus-boshrelease
bosh upload release https://github.com/cloudfoundry-community/node-exporter-boshrelease/releases/download/v1.0.0/node-exporter-1.0.0.tgz
```
You can find root_ca_certificate file on the OpsManager VM in ```/var/tempest/workspaces/default/root_ca_certificate```.

## Create UAA clients
Key components of this BOSH release are [firehose_exporter](https://github.com/cloudfoundry-community/firehose_exporter),  [bosh_exporter](https://github.com/cloudfoundry-community/bosh_exporter) and [cf_exporter](https://github.com/cloudfoundry-community/cf_exporter/) which retrieve the data (from CF firehose, BOSH director and Cloud Controller API respectively) and present it in the Prometheus format. Each of those exporters require credentials to access the data source. IMPORTANT: these users have to be created in two different UAA instances. For the firehose and CF credentials, you use the main UAA instance of a Cloud Foundry deployment (where you would normally create users/clients, such as those for any other nozzles). For bosh_exporter however, you need to use the UAA which is colocated with the BOSH Director.

### Create client for firehose_exporter
This process is explained here: https://github.com/cloudfoundry-community/firehose_exporter
```bash
uaac target https://uaa.SYSTEM_DOMAIN --skip-ssl-validation
uaac token client get admin -s <YOUR ADMIN CLIENT SECRET>
uaac client add prometheus-firehose \
  --name prometheus-firehose \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose
```
Edit name and secret values. You will need to put them in the manifest later.


### Create user for cf_exporter
```bash
uaac user add prometheus-cf --password prometheus-client-secret  --emails prometheus-cf
uaac member add cloud_controller.admin prometheus-cf
```
Edit name and secret values. You will need to put them in the manifest later.

### Create client for bosh_exporter
```bash
uaac target https://BOSH_DIRECTOR:8443 --skip-ssl-validation
uaac token owner get login -s Uaa-Login-Client-Credentials
User name:  admin
Password:  Uaa-Admin-User-Credentials
  uaac client add prometheus-bosh \
  --name prometheus-bosh \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities bosh.read \
  --scope bosh.read
```
Edit name and secret values. You will need to put them in the manifest later.

## Create MySQL user
Given that PCF uses MySQL internally you should also monitor it. To do that, create a MySQL user and configure it in local.yml later.
```
bosh ssh mysql
mysql -u root -p
Enter password: (OpsManager -> ERT -> Credentials -> Mysql Admin Credentials)
CREATE USER 'exporter' IDENTIFIED BY 'CHANGE_ME';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter' WITH MAX_USER_CONNECTIONS 3;
```
More information about mysqld_exporter is available [here](https://github.com/prometheus/mysqld_exporter).

## Prepare your manifest based on the template from this repo
Since prometheus.yml is changing often to add more functionality (or to adjust it to the change in the bosh release itself) you don't have to edit it. Local configuration which needs to be adjusted is in the local.yml file. Edit URLs, credentials and everything else you need and then merge it with prometheus.yml. So the steps are:

* Copy prometheus.yml and local.yml from this repo to your working directory
* Edit CHANGE_ME and other placeholders
* Merge the two files:
```
bosh-cli interpolate prometheus.yml -l local.yml > manifest.yml
```
* Once the manifest is ready, deploy:
```
bosh deployment manifest.yml
bosh -n deploy
```
To generate VM passwords you can use:
```
ruby -e 'require "securerandom"; require "unix_crypt"; printf("%s\n", UnixCrypt::SHA512.build(SecureRandom.hex(16), SecureRandom.hex(8)))'
```
or (change MY_PASSWORD to the password you want):
```
pip install passlib
python -c 'from passlib.hash import sha512_crypt as sc; print sc.encrypt("MY_PASSWORD", salt="random", relaxed=True)'
```
or (requires whois package installed on a Linux machines):
```
mkpasswd -s -m sha-512
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
* https://NGINX:3000 to access Grafana (default credentials: admin/CHANGE_ME)
* https://NGINX:9090 to access Prometheus

There is a number of ready to use Dashboards that should install automatically. You can edit them in Grafana or create your own. They are coming from [prometheus-boshrelease/src](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/src).

## Alertmanager
The `prometheus-boshrelease` does include some predefined alerts for CloudFoundry as well as for BOSH. You can find the alert definitions in [prometheus-boshrelease/src](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/src). Check the `*.alerts` rule files in the corresponding folders. If you create new alerts make sure to add them to the `prometheus.yml` -  the path to the alert rule file as well as a job release for additional new exporters.
Access the AlertManager to see active alerts or silence them:
* https://NGINX:9093

All configured rules as well as their current state can be viewed by accessing Prometheus:
* https://NGINX:9090/alerts

Below and example config for `prometheus.yml` to send alerts to slack:
```
- name: alertmanager
    release: prometheus
    properties:
      alertmanager:
        receivers:
          - name: default-receiver
            slack_configs:
            - api_url: https://hooks.slack.com/services/....
              channel: 'slack-channel'
              send_resolved: true
              pretext: "text before the actual alert message"
        route:
          receiver: default-receiver
```
To check your AlertManager configuration you can execute:
```
curl -H "Content-Type: application/json" -d '[{"labels":{"alertname":"TestAlert1"}}]' <alertmanager>:9093/api/v1/alerts
```
This should trigger a test alert.
