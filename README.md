# Automation Alchemy - Sherlock Logs

Automation Alchemy is a reproducible local DevOps environment built on six Ubuntu virtual machines. It provisions a load-balanced containerized application, a Jenkins CI/CD pipeline with a private Docker Registry and rollback support, and a complete metrics and centralized logging platform.

The entire environment can be created from a clean state with Vagrant and Ansible. It is intended as an educational infrastructure project and demonstrates infrastructure as code, service isolation, deployment automation, observability, alerting, and operational recovery.

## Highlights

- Six Ubuntu 22.04 VMs created with Vagrant and VirtualBox
- Idempotent Ansible roles for provisioning and deployment
- NGINX load balancing across two frontend servers
- Containerized Node.js backend and NGINX frontend
- Jenkins Configuration as Code and a pipeline stored in the repository
- Versioned images in a private Docker Registry
- Validated application rollback without rebuilding images
- Prometheus metrics from Node Exporter, cAdvisor, the application, and Elasticsearch
- Provisioned Grafana dashboards, Grafana-managed alerts, and Prometheus alert rules
- Filebeat, Logstash, Elasticsearch, and Kibana centralized logging
- Grouped alert delivery to Discord through Alertmanager and a local relay
- UFW network restrictions and key-only SSH access
- Automated health checks and observability smoke tests

## Architecture

```mermaid
flowchart LR
    User["Browser"] --> LB["lb-01<br/>NGINX :80"]
    LB --> W1["web-01<br/>Frontend :8080"]
    LB --> W2["web-02<br/>Frontend :8080"]
    W1 --> APP["app-01<br/>Backend :3000"]
    W2 --> APP

    J["ci-01<br/>Jenkins :8080"] --> R["Private Registry :5000"]
    R --> W1
    R --> W2
    R --> APP
    J -. "Ansible deploy" .-> W1
    J -. "Ansible deploy" .-> W2
    J -. "Ansible deploy" .-> APP

    Agents["Node Exporter + cAdvisor<br/>Filebeat agents"] --> MON["monitoring-01"]
    APP -->|"/prometheus"| MON
    MON --> P["Prometheus + Alertmanager"]
    MON --> G["Grafana"]
    MON --> ELK["Logstash + 2-node Elasticsearch + Kibana"]
```

Application traffic follows this path:

```text
Browser -> lb-01:80 -> web-01:8080 / web-02:8080 -> app-01:3000
```

The frontend instances proxy API requests to the backend. Jenkins builds and pushes versioned images to the local registry, then uses Ansible to deploy the selected tag.

### Virtual machines

| VM | IP address | vCPU | RAM | Primary role |
|---|---:|---:|---:|---|
| `lb-01` | `192.168.56.10` | 1 | 640 MB | NGINX load balancer |
| `web-01` | `192.168.56.11` | 1 | 640 MB | Frontend container |
| `web-02` | `192.168.56.12` | 1 | 640 MB | Frontend container |
| `app-01` | `192.168.56.13` | 1 | 768 MB | Backend container |
| `ci-01` | `192.168.56.14` | 2 | 2048 MB | Jenkins and Docker Registry |
| `monitoring-01` | `192.168.56.15` | 2 | 5120 MB | Metrics, alerting, logs, and dashboards |

The VMs are assigned 8 vCPUs and 9,856 MB of RAM in total.

## Technology Stack

| Area | Technologies |
|---|---|
| Virtualization | Vagrant, VirtualBox, Ubuntu 22.04 |
| Automation | Ansible, Bash, Make |
| Application | Node.js, Express, NGINX, Docker |
| Traffic | NGINX load balancer and reverse proxies |
| CI/CD | Jenkins, Jenkins Configuration as Code, private Docker Registry |
| Metrics | Prometheus, Node Exporter, cAdvisor, Elasticsearch Exporter |
| Dashboards and alerts | Grafana, Alertmanager, Prometheus rules |
| Centralized logging | Filebeat, Logstash, Elasticsearch, Kibana |
| Security | UFW, SSH key authentication, restricted service ports |

## Prerequisites

The project is designed for a Windows host with:

- VirtualBox
- Vagrant
- WSL2 with an Ubuntu distribution
- Ansible, Make, Python 3, curl, and OpenSSH installed in WSL
- At least 14 GB of host RAM recommended
- At least 60 GB of free disk space recommended

Install the Ansible collection used by the firewall role:

```bash
ansible-galaxy collection install community.general
```

Vagrant commands should be run from PowerShell. Ansible and Make commands should be run from WSL inside the project directory.

Before the first provisioning run, make sure `ssh_key_dir` in `ansible/inventory.ini` points to the same WSL directory used by `scripts/sync-vagrant-keys.sh`:

```ini
ssh_key_dir=/home/<wsl-user>/.ssh/automation-alchemy
```

## Quick Start

### 1. Start the VMs

From PowerShell in the repository root:

```powershell
vagrant up --no-parallel
vagrant status
```

All six machines should report `running`.

### 2. Provision the environment

Open WSL and enter the repository:

```bash
cd /mnt/c/Users/<windows-user>/sherlock-logs
make provision
```

`make provision` performs the complete workflow:

1. Reads optional values from `.env`.
2. Synchronizes the Vagrant SSH keys for Ansible.
3. Bootstraps the `devops` user when needed.
4. Applies security and SSH hardening.
5. Installs Docker on the required hosts.
6. configures Jenkins and the private registry.
7. Builds, pushes, and deploys the application images.
8. Configures the load balancer.
9. Installs the metrics and logging agents.
10. Deploys the monitoring and logging stack after the scrape targets are ready.

Provisioning pulls several large monitoring images and can take time on the first run.

### 3. Verify the deployment

```bash
make ping
make app-test
make sherlock-test
make monitoring-status
```

The application should then be available at [http://192.168.56.10](http://192.168.56.10).

## Optional Environment Configuration

The local `.env` file is ignored by Git. It can contain:

```dotenv
DEVOPS_PASSWORD=your-local-devops-password
DISCORD_REVIEW_WEBHOOK_URL=https://discord.com/api/webhooks/...
DISCORD_ALERT_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

`DEVOPS_PASSWORD` defaults to `devops` when it is not supplied. `DISCORD_REVIEW_WEBHOOK_URL` is optional and is used by Jenkins. `DISCORD_ALERT_WEBHOOK_URL` is used by monitoring alerts; when it is omitted, monitoring reuses `DISCORD_REVIEW_WEBHOOK_URL`. Do not commit real webhook URLs or other secrets.

## Service Endpoints

| Service | Address | Credentials |
|---|---|---|
| Application | [http://192.168.56.10](http://192.168.56.10) | None |
| Application health through LB | [http://192.168.56.10/api/health](http://192.168.56.10/api/health) | None |
| Jenkins | [http://192.168.56.14:8080](http://192.168.56.14:8080) | `admin` / `admin` |
| Docker Registry | [http://192.168.56.14:5000/v2/_catalog](http://192.168.56.14:5000/v2/_catalog) | None |
| Prometheus | [http://192.168.56.15:9090](http://192.168.56.15:9090) | None |
| Alertmanager | [http://192.168.56.15:9093](http://192.168.56.15:9093) | None |
| Grafana | [http://192.168.56.15:3000](http://192.168.56.15:3000) | `admin` / `sherlock` |
| Elasticsearch | [http://192.168.56.15:9200](http://192.168.56.15:9200) | None |
| Kibana | [http://192.168.56.15:5601](http://192.168.56.15:5601) | None |

All credentials are local demonstration credentials. The environment is not intended to be exposed to an untrusted network.

## Application

The backend is a small Express service with structured JSON logging and Prometheus instrumentation.

| Endpoint | Purpose |
|---|---|
| `/health` | JSON health response |
| `/metrics` | JSON server information used by the frontend |
| `/prometheus` | Prometheus-format application metrics |
| `/simulate-error` | Generates a controlled HTTP 500 and error log for demonstrations |

The backend records request counts, request duration histograms, response status labels, runtime metrics, and a custom operation counter. The two frontend containers display runtime information and proxy API requests to the backend.

## CI/CD Pipeline

Jenkins is configured automatically from `ci/jenkins/casc.yaml`. The `automation-alchemy-deploy` job executes `ci/Jenkinsfile` from the configured Git repository and branch.

Before using a fork or a school repository, update the repository URL and branch in `ci/jenkins/casc.yaml`, then apply the Jenkins configuration again:

```bash
make jenkins-restore
```

Pipeline stages:

1. Check out source code.
2. Validate Grafana dashboards and alerting provisioning, Kibana saved objects, and Prometheus configuration/rules.
3. Select normal deployment or rollback mode.
4. Validate a requested rollback tag.
5. Build backend and frontend images for normal deployments.
6. Push versioned and `latest` tags to the private registry.
7. Deploy the application with Ansible.
8. Deploy or refresh observability.
9. Run application and Sherlock Logs smoke tests.
10. Send an optional Discord result notification.

Normal builds create matching image tags:

```text
192.168.56.14:5000/automation-backend:<jenkins-build-number>
192.168.56.14:5000/automation-frontend:<jenkins-build-number>
```

To run a normal deployment, open Jenkins, select `automation-alchemy-deploy`, and choose **Build Now**.

## Rollback

Rollback redeploys an existing pair of image tags without rebuilding them. The workflow validates that the requested tag exists for both images before changing the running containers.

From WSL:

```bash
make image-tags
make deployed-images
make rollback VERSION=<existing-build-number>
```

Rollback can also be demonstrated from Jenkins by starting `automation-alchemy-deploy` with the `ROLLBACK_TAG` parameter.

## Observability

### Metrics

Prometheus scrapes:

- Node Exporter on all six VMs
- cAdvisor on all Docker hosts
- the backend `/prometheus` endpoint
- Prometheus itself
- Elasticsearch Exporter

Metrics are retained for seven days. Grafana automatically provisions the Prometheus datasource and three dashboards in the `Sherlock Logs` folder:

- **VM Performance** - CPU, memory, disk I/O, and network traffic
- **Docker Containers** - running containers, CPU, memory, and restart activity
- **Application Performance** - request rate, latency, errors, and custom operations

Docker 29 uses the containerd image store. cAdvisor is therefore started with disk container metrics disabled to avoid the current `overlayfs` layer lookup incompatibility. CPU, memory, network, metadata, and restart metrics remain available; host disk metrics are collected by Node Exporter.

### Alerting

Provisioned Prometheus rules cover:

- high VM CPU and memory usage
- low VM disk space
- unreachable VM exporters
- frequent container restarts
- high container memory usage
- unhealthy Elasticsearch cluster state
- combined CPU and memory pressure
- elevated application HTTP 5xx rate

Grafana also provisions managed alerts for VM CPU above 80%, memory above 90%, and available disk below 20%. These rules use the Prometheus datasource but are evaluated by Grafana, so both Grafana-managed and Prometheus-managed alerting can be demonstrated. The overlap is intentional for the review; in production, keep one evaluator for each condition or route duplicate rules to a non-paging receiver.

Prometheus and Grafana send alerts to Alertmanager. Logstash also creates an Alertmanager alert when it matches a structured `error`/`fatal` application event or common fatal text patterns. Alertmanager groups alerts, waits for related events, and limits repeats to once every four hours. Its webhook receiver calls the local notification relay, which forwards a compact message to Discord when `DISCORD_ALERT_WEBHOOK_URL` is configured.

```text
Prometheus rules -----------+
Grafana-managed rules ------+--> Alertmanager --> notification relay --> Discord
Logstash log-pattern match -+
```

Alerts can be inspected in Prometheus, Grafana, and Alertmanager even when Discord is not configured.

### Centralized logging

The logging path is:

```text
VM and container logs -> Filebeat -> Logstash -> Elasticsearch -> Kibana
```

Filebeat collects system logs from every VM and Docker JSON logs from Docker hosts. Logstash separates events into these index families:

- `system-logs-*`
- `application-logs-*`
- `docker-logs-*`

Elasticsearch runs as a two-node cluster on `monitoring-01`. With both nodes running and the default one-replica index layout, cluster status is green. Stopping `elasticsearch-2` leaves primary shards available but unassigned replicas change the cluster to yellow, providing a safe alert demonstration.

Kibana saved objects are imported automatically during provisioning. Each required dashboard combines a Vega event-volume chart with a searchable, filterable log table:

- **System Logs Dashboard**
- **Application Logs Dashboard**
- **Docker Logs Dashboard**

### Historical data and retention

Prometheus stores metrics in a named volume with a seven-day retention period. Elasticsearch stores both nodes in persistent volumes and writes daily indices. For longer production retention, increase `--storage.tsdb.retention.time` or use remote write for metrics, and apply an Elasticsearch ILM policy that rolls over indices and deletes or moves them after the required number of days. Alertmanager and Grafana also use persistent volumes.

## Review Preparation

### Push versus pull monitoring

In a pull model, Prometheus periodically requests `/metrics` from known targets. This centralizes scrape scheduling, makes target failures visible through the `up` metric, and lets an operator query an exporter directly while troubleshooting. In a push model, applications send data to a collector; this is useful for short-lived jobs or hosts that cannot accept inbound connections, but adds retry, buffering, and backpressure logic to every sender. Prometheus uses pull by default for service discovery, consistent collection intervals, and simple health detection. Short-lived jobs can use Pushgateway when necessary.

### ELK component roles

- **Elasticsearch** stores, indexes, replicates, and searches events.
- **Logstash** receives Beats events, applies conditions and transformations, selects an index, and generates alerts for matching log patterns.
- **Kibana** provides data views, KQL search, filters, visualizations, and dashboards over Elasticsearch data.
- **Filebeat** is the lightweight shipper installed on the observed VMs; it is not part of the ELK acronym but feeds Logstash.

### Prometheus compared with Nagios and Zabbix

Prometheus is strong for dynamic infrastructure, dimensional labels, PromQL, service discovery, and cloud-native exporters. It is easy to integrate with instrumented applications but does not provide unlimited built-in retention, and high-cardinality labels require care. Nagios is mature and simple for host/service checks but is less natural for exploratory time-series queries. Zabbix provides integrated inventory, templates, agents, UI, and longer-term storage, but is heavier to operate and its query model is less flexible than PromQL for application metrics.

### Scrape interval and exporter troubleshooting

The global scrape interval is `15s` in `monitoring/prometheus/prometheus.yml`. It can be changed globally or overridden inside one `scrape_config`, for example `scrape_interval: 30s`. After changing it, validate with `promtool`, redeploy observability, and inspect Prometheus **Status -> Targets**.

For a missing Node Exporter or cAdvisor target, check the service/container, listen address, target IP and port, UFW source rule, Docker port mapping, and Prometheus target error. Typical commands are `systemctl status prometheus-node-exporter`, `docker logs cadvisor`, `ss -lntp`, and `curl http://target:port/metrics` from `monitoring-01`.

### Grafana, Kibana, and Datadog

Grafana is datasource-neutral and especially strong for Prometheus time-series dashboards, reusable variables, PromQL exploration, and self-hosted alerting. Kibana is the better tool here for full-text log search and Elasticsearch fields. Datadog provides an integrated hosted platform and many managed integrations, but has recurring cost, vendor dependency, and less control over data locality.

In Grafana's query editor, select the Prometheus datasource, enter PromQL, filter with label selectors such as `{instance=~"$instance"}`, and aggregate with operators such as `sum by(instance)` or `avg by(instance)`. In Kibana, use KQL such as `application.level: "error" and vm_name: "app-01"`, the time picker, field filters, and dashboard drill-down into Discover.

### Application metrics and log parsing

The backend uses `prom-client`: counters are incremented with `inc()`, histograms record durations with `observe()`, default runtime metrics are registered automatically, and `/prometheus` returns the registry using the Prometheus content type. Avoid unbounded labels such as user IDs or raw URLs because they create excessive time-series cardinality.

Application logs are structured JSON. Filebeat decodes JSON into the `application` object and preserves parsing errors with `add_error_key`; Logstash keeps unmatched events searchable in system or Docker indices. For mixed formats, add conditional `json`, `grok`, or `dissect` filters, tag failures such as `_grokparsefailure`, retain the original `message`, and monitor the failure tag rather than dropping events.

### Dynamic agent configuration and collection troubleshooting

The Jenkins observability stage runs `ansible/observability.yml`. Inventory groups decide which hosts receive cAdvisor, while `group_vars` supplies ports, addresses, image versions, and retention. A different environment can provide another inventory or override variables with `-e` without duplicating the role.

When metrics disappear, work from the source outward: exporter process, local `/metrics`, firewall, Prometheus target health, metric name/labels, Grafana time range, and dashboard query. Historical gaps cannot be reconstructed after collection is lost, which is why target health and disk capacity should also be monitored.

### Alert tuning and alert fatigue

Thresholds should represent actionable conditions, not normal short spikes. The `for` duration rejects transient peaks; Alertmanager grouping combines related instances; `group_interval` and `repeat_interval` prevent repeated messages; silences cover maintenance. Tune from historical baselines, use separate warning and critical levels, add recovery hysteresis where available, and include runbook context. The container-memory rule excludes missing or effectively unlimited cgroup limits to avoid false alerts.

The advanced `HighCPUAndLowMemory` rule demonstrates vector matching with `and on(instance)`. `ApplicationHighErrorRate` combines two five-minute `rate()` aggregations and `clamp_min()` to avoid division by zero.

### Alert demonstration commands

Run stress tests on one disposable lab VM and remove all test artifacts afterward. Prometheus evaluates every 15 seconds; rules with `for: 5m` need slightly more than five continuous minutes.

```bash
# CPU above 80% for more than 5 minutes
stress-ng --cpu 0 --timeout 360s

# Memory above 90% for more than 5 minutes
stress-ng --vm 1 --vm-bytes 92% --vm-keep --timeout 360s

# Disk below 20%; inspect df first and adjust the size for the VM
df -h /
sudo fallocate -l 10G /var/tmp/review-large-file.img
sudo rm -f /var/tmp/review-large-file.img

# More than three container restarts in 15 minutes
docker run -d --restart=always --name test_container ubuntu \
  /bin/bash -c "sleep 10; exit 1"
docker rm -f test_container

# Container memory above 80% of a 512 MiB limit
docker run --rm -d -m 512m --name memory_test python:3.12-alpine \
  python -c "x=bytearray(450*1024*1024); import time; time.sleep(360)"
docker rm -f memory_test

# Safely simulate an unreachable VM exporter, then restore it
sudo systemctl stop prometheus-node-exporter
sudo systemctl start prometheus-node-exporter

# Generate a structured application error for the Logstash pattern alert
curl http://192.168.56.13:3000/simulate-error
```

Demonstrate the Elasticsearch transition on `monitoring-01`:

```bash
cd /opt/sherlock-logs
curl -s http://127.0.0.1:9200/_cluster/health?pretty
sudo docker compose stop elasticsearch-2
# Wait at least two minutes for ElasticsearchClusterNotGreen.
curl -s http://127.0.0.1:9200/_cluster/health?pretty
sudo docker compose start elasticsearch-2
curl -s 'http://127.0.0.1:9200/_cluster/health?wait_for_status=green&timeout=120s&pretty'
```

## Security Model

The project applies practical controls for a local lab:

- SSH password authentication is disabled.
- Root SSH login is disabled.
- Only the `devops` user is allowed over SSH after hardening.
- UFW defaults to denying incoming traffic.
- Frontend ports accept traffic only from the load balancer.
- The backend accepts application traffic only from the frontend servers.
- Exporter ports accept scrape traffic only from the monitoring server.
- Monitoring interfaces are limited to the host-only `192.168.56.0/24` network.
- Sensitive Jenkins environment data is written with restricted permissions.

This is an educational local environment. It intentionally uses HTTP and demonstration credentials; the two-node Elasticsearch cluster also runs on one monitoring VM, so additional isolation and hardening would be required for production use.

## Useful Commands

| Command | Description |
|---|---|
| `make up` | Start all VMs without parallel boot |
| `make status` | Show VM state |
| `make sync-keys` | Synchronize Vagrant SSH keys for Ansible |
| `make ping` | Test Ansible connectivity |
| `make provision` | Provision the complete environment |
| `make observability` | Redeploy monitoring, logging, and agents |
| `make app-test` | Run application health checks |
| `make sherlock-test` | Validate monitoring endpoints, targets, rules, and log indices |
| `make monitoring-status` | Show monitoring container status |
| `make monitoring-logs` | Show recent monitoring container logs |
| `make registry-test` | Query the Registry catalog |
| `make registry-smoke` | Push and pull a test image through the Registry |
| `make image-tags` | List backend and frontend tags |
| `make deployed-images` | Show the currently deployed images |
| `make rollback VERSION=<tag>` | Redeploy an existing image version |
| `make jenkins-status` | Show Jenkins container status |
| `make jenkins-logs` | Show recent Jenkins logs |
| `make jenkins-restore` | Reapply Jenkins Configuration as Code |
| `make security-check` | Inspect the hardened user and sudo configuration |
| `make ssh-negative-test` | Verify that forbidden SSH users are rejected |
| `make discord-test` | Send an optional Discord test notification |
| `make destroy` | Destroy all Vagrant VMs |

## Project Structure

```text
.
|-- Vagrantfile                     # Six-VM topology
|-- Makefile                        # Operator commands
|-- ansible/
|   |-- inventory.ini               # Host groups and SSH configuration
|   |-- bootstrap.yml               # Initial devops-user bootstrap
|   |-- site.yml                    # Full infrastructure provisioning
|   |-- deploy.yml                  # Application deployment
|   |-- rollback.yml                # Validated rollback
|   |-- observability.yml           # Monitoring/logging deployment
|   `-- roles/                       # Reusable Ansible roles
|-- app/
|   |-- backend/                    # Express application and Dockerfile
|   `-- frontend/                   # Static frontend, NGINX, and Dockerfile
|-- ci/
|   |-- Jenkinsfile                 # CI/CD pipeline
|   `-- jenkins/                    # Jenkins image, plugins, and JCasC
|-- monitoring/
|   |-- docker-compose.yml          # Central observability stack
|   |-- prometheus/                 # Scrape and alert configuration
|   |-- grafana/                    # Provisioned datasource, dashboards, and alerts
|   |-- alertmanager/               # Alert routing
|   |-- logstash/                   # Log processing pipeline
|   |-- kibana/                     # Data views, searches, visualizations, dashboards
|   `-- notification-relay/         # Safe Alertmanager-to-Discord adapter
`-- scripts/                        # Bootstrap, smoke tests, and operations
```

## Demo Checklist

For a short project review:

```bash
make status
make ping
make app-test
make sherlock-test
make deployed-images
```

Then demonstrate:

1. Application load balancing at `http://192.168.56.10`.
2. A successful Jenkins pipeline build.
3. The three Grafana dashboards and three Grafana-managed alert rules.
4. Prometheus targets and alert rules.
5. A green two-node Elasticsearch cluster.
6. Kibana system, application, and Docker charts plus filtered log tables.
7. `/simulate-error` appearing in Kibana and as `LogPatternDetected` in Alertmanager.
8. A rollback to a previous Jenkins build tag.

## Troubleshooting

### Ansible cannot connect

```bash
make sync-keys
make ping
```

If the VMs were rebuilt, always synchronize their new Vagrant keys before provisioning.

### Prometheus, Grafana, or Kibana is not ready

```bash
make monitoring-status
make monitoring-logs
make observability
```

Elasticsearch and Kibana may need several minutes to become ready after a cold start.

### Grafana dashboards are empty

First confirm that Prometheus targets are `UP` at `http://192.168.56.15:9090/targets`, then rerun:

```bash
make observability
```

Refresh Grafana after the playbook completes. The Ansible role enforces readable provisioning permissions and deploys the Docker 29-compatible cAdvisor configuration.

### Elasticsearch is yellow before the alert demonstration

Both Elasticsearch containers must be running during normal operation:

```bash
cd /opt/sherlock-logs
sudo docker compose ps elasticsearch elasticsearch-2
sudo docker compose start elasticsearch-2
curl -s 'http://127.0.0.1:9200/_cluster/health?wait_for_status=green&timeout=120s&pretty'
```

### Discord monitoring notifications are missing

Confirm that `DISCORD_ALERT_WEBHOOK_URL` or the fallback `DISCORD_REVIEW_WEBHOOK_URL` is present in the local ignored `.env`, rerun `make observability`, and inspect:

```bash
make monitoring-logs
curl http://192.168.56.13:3000/simulate-error
```

Alertmanager should show `LogPatternDetected` even when no Discord webhook is configured.

### Jenkins cannot check out the repository

Verify the Git URL and branch in `ci/jenkins/casc.yaml`, push that branch, and run:

```bash
make jenkins-restore
```

### A rollback tag is rejected

```bash
make image-tags
```

The tag must exist for both `automation-backend` and `automation-frontend`, and `latest` is intentionally rejected as a rollback target.

### Vagrant runs out of host resources

Stop other VMs and containers, ensure sufficient free disk space, and start the machines sequentially with `vagrant up --no-parallel`.

## Cleanup

Destroy the lab from PowerShell:

```powershell
vagrant destroy -f
```

This removes the six VMs. Repository files remain unchanged.
