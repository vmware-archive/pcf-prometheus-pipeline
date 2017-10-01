
**WARNING**
The old version of this repository is deprecated. If you need it, please use [this tag](https://github.com/pivotal-cf/prometheus-on-PCF/tree/74fba4b3401340278d9cb66b4a8076b328de37b8)
**WARNING**

.
.
.
.
.

# Prometheus BOSH release on Pivotal Cloud Foundry

This is currently work in progress. Key changes I'm working on:
- use manifests from prometheus-boshrelease (with the [required modifications](pcf-cloud-config-ops.yml))
- switch to [bosh-deployment resource](https://github.com/cloudfoundry/bosh-deployment-resource)
- switch everything to [BOSH CLI v2](https://github.com/cloudfoundry/bosh-cli)

# How it works
This is a high-level overview of monitoring Cloud Foundry with Prometheus
![logical diagram](https://github.com/mkuratczyk/prometheus-on-PCF/blob/master/docs/logical-diagram.png)

Notes:
* since Prometheus uses a pull mechanism, connections are initiated by Prometheus
* if you deploy the bosh release using the provided manifest, exporters are colocated with Prometheus (except node_exporter which is a BOSH add-on and runs on all VMs)
  NOTE: of course you can create your own manifest or an ops file to deploy jobs in a different way
* prometheus-boshrelease includes a number of other exporters you can use which are not used in this example; you can see them [here](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/manifests/operators)
* in a production environment you should probably put firehose_exporter on a separate VM to scale it out independently

## Installation
It is recommended to use the pipeline to deploy Prometheus (or anything else for that matter). To do that:
- clone this repository
- copy params.yml to a different place
- edit the params accordingly (there are helpful comments)
- fly -t target set-pipeline -p deploy-prometheus -c pipeline/pipeline.yml -l your-params.yml
- run the pipeline

## Manual installation

```
TODO
```

You can find root_ca_certificate file on the OpsManager VM in ```/var/tempest/workspaces/default/root_ca_certificate```.

### Create UAA clients
If you are using the pipeline, UAA clients are created automatically so you don't need to do this.

Key components of this BOSH release are [firehose_exporter](https://github.com/cloudfoundry-community/firehose_exporter),  [bosh_exporter](https://github.com/cloudfoundry-community/bosh_exporter) and [cf_exporter](https://github.com/cloudfoundry-community/cf_exporter/) which retrieve the data (from CF firehose, BOSH director and Cloud Controller API respectively) and present it in the Prometheus format. Each of those exporters require credentials to access the data source. IMPORTANT: these users have to be created in two different UAA instances. For the firehose and CF credentials, you use the main UAA instance of a Cloud Foundry deployment (where you would normally create users/clients, such as those for any other nozzles). For bosh_exporter however, you need to use the UAA which is colocated with the BOSH Director.

#### Create clients for firehose_exporter and cf_exporter
This process is explained here: https://github.com/cloudfoundry-community/firehose_exporter
```bash
uaac target https://uaa.SYSTEM_DOMAIN --skip-ssl-validation
uaac token client get admin -s <YOUR ADMIN CLIENT SECRET>
uaac client add prometheus-firehose \
  --name prometheus-firehose \
  --secret prometheus-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities doppler.firehose

uaac client add prometheus-cf \
  --name prometheus-cf \
  --secret prometheus-cf-client-secret \
  --authorized_grant_types client_credentials,refresh_token \
  --authorities cloud_controller.admin
```
Edit name and secret values. You will need to put them in the manifest later.

#### Create client for bosh_exporter
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

### Create MySQL user
Given that PCF uses MySQL internally you should also monitor it. To do that, create a MySQL user and configure it in local.yml later.
```
bosh ssh mysql
mysql -u root -p
Enter password: (OpsManager -> ERT -> Credentials -> Mysql Admin Credentials)
CREATE USER 'exporter' IDENTIFIED BY 'CHANGE_ME';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter' WITH MAX_USER_CONNECTIONS 3;
```
More information about mysqld_exporter is available [here](https://github.com/prometheus/mysqld_exporter).

### Deploy node_exporter on all nodes
node_exporter is a core Prometheus exporter which provides detailed OS-level information. Using BOSH add-ons feature it's very easy to install node_exporter on all BOSH-provisioned VMs. Take the example runtime.yml (adjust the prometheus release version if needed) and run:
```
bosh update-runtime-config runtime.yml
```
Once that's done, any VM (re)created by BOSH will be running node_exporter. The manifest is already prepared to consume that data.

## Connect to Grafana
If the deployment was successful use ```bosh vms``` to find out the IP address of your nginx server. Then connect:
* https://NGINX:3000 to access Grafana
* https://NGINX:9090 to access Prometheus

There is a number of ready to use Dashboards that should install automatically. You can edit them in Grafana or create your own. They are coming from [prometheus-boshrelease/jobs](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/jobs).

## Alertmanager
The `prometheus-boshrelease` does include some predefined alerts for CloudFoundry as well as for BOSH. You can find the alert definitions in [prometheus-boshrelease/job](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/jobs). Check the `*.alerts` rule files in the corresponding folders. If you create new alerts make sure to add them to the `prometheus.yml` -  the path to the alert rule file as well as a job release for additional new exporters.
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
              text: "{{ .CommonAnnotations.description }}"
        route:
          receiver: default-receiver
```
To check your AlertManager configuration you can execute:
```
curl -H "Content-Type: application/json" -d '[{"labels":{"alertname":"TestAlert1"}}]' <alertmanager>:9093/api/v1/alerts
```
This should trigger a test alert.
