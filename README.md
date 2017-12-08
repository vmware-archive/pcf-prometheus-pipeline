# Concourse pipeline for deploying Prometheus to monitor Pivotal Cloud Foundry

This pipeline is only compatible with PCF 1.12 and newer. If you are using an older version then please use [this pipeline](https://github.com/pivotal-cf/prometheus-on-PCF/tree/74fba4b3401340278d9cb66b4a8076b328de37b8) instead.

Main differences compared to the old pipeline:

- it uses [manifests from prometheus-boshrelease](https://github.com/bosh-prometheus/prometheus-boshrelease/tree/master/manifests)
- it deploys more VMs (firehose_exporter has a dedicated VM, there is a database for Grafana)
- pipeline property names changed to match the manifests
- it automatically discovers some of the properties by querying OpsManager (that's why it requires PCF 1.12+)
- it uses a named runtime-config (a relatively new BOSH feature)
- it only uses BOSH CLI v2 (directly and through [BOSH Deployment Resource](https://github.com/cloudfoundry/bosh-deployment-resource))

This pipeline deploys Prometheus BOSH release to monitor PCF but can be deployed to a separate BOSH Director.
Use `director_for_deployment` property to configure whether you want to deploy it to OpsManager Director or a separate BOSH Director.

## How it works

This is a high-level overview of monitoring Cloud Foundry with Prometheus
![logical diagram](https://github.com/mkuratczyk/prometheus-on-PCF/blob/master/docs/logical-diagram.png)

Notes:

- since Prometheus uses a pull mechanism, connections are initiated by Prometheus
- most of exporters are colocated with Prometheus (exceptions: firehose exporter has a dedicated VM and node_exporter is a BOSH add-on and runs on all VMs)
- prometheus-boshrelease includes a number of other exporters you can use which are not used in this example; you can see them [here](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/manifests/operators)

## Installation

First of all, have a Concourse running. If you don't have Concourse yet, you can quickly spin one up using [BUCC](https://github.com/starkandwayne/bucc) or [Concourse-Up](https://github.com/EngineerBetter/concourse-up).

- clone this repository
- copy pipeline/params.yml to a different place (to avoid polluting the GIT repo)
- edit the params accordingly (there are helpful comments)
- fly -t target set-pipeline -p deploy-prometheus -c pipeline/pipeline.yml -l your-params.yml
- fly -t target unpause-pipeline -p deploy-prometheus
- trigger create-uaa-clients job manually
- trigger install-node-exporter job manually
- trigger deploy job manually

## How to use it

If the deployment was successful use ```bosh vms``` to find out the IP address of your nginx server. Then connect:

- https://NGINX:3000 to access Grafana
- https://NGINX:9090 to access Prometheus

There is a number of ready to use Dashboards that should be installed automatically. You can edit them in Grafana or create your own. They are coming from [prometheus-boshrelease/jobs](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/jobs).

## Alertmanager

*Warning*
Current version doesn't allow you to easily configure your alertmanager notifications. This should be fixed soon.

The `prometheus-boshrelease` does include some predefined alerts for CloudFoundry as well as for BOSH. You can find the alert definitions in [prometheus-boshrelease/jobs](https://github.com/cloudfoundry-community/prometheus-boshrelease/tree/master/jobs). Check the `*.alerts` rule files in the corresponding folders.

Access the AlertManager to see active alerts or silence them:

- https://NGINX:9093

All configured rules as well as their current state can be viewed by accessing Prometheus:

- https://NGINX:9090/alerts
