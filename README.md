# devstats-helm-example

DevStats Deployment on Kubernetes using Helm. This is an example deployment of few CNCF projects.

Helm chart in `devstats-helm-example`.

# Ingress first

Please install ingress first, for example `AWS`: `AWS_INGRESS.md`. Then install SSL certificates `SSL.md`.

# Usage

You should set namespace to 'devstats' first: `./switch_namespace.sh devstats`.

Please provide secret values for each file in `./secrets/*.secret.example` saving it as `./secrets/*.secret` or specify them from the command line.

Please note that `vim` automatically adds new line to all text files, to remove it run `truncate -s -1` on a saved file.

List of secrets:
- File `secrets/PG_ADMIN_USER.secret` or --set `pgAdminUser=...` setup postgres admin user name.
- File `secrets/PG_HOST.secret` or --set `pgHost=...` setup postgres host name.
- File `secrets/PG_HOST_RO.secret` or --set `pgHostRO=...` setup postgres host name (read-only).
- File `secrets/PG_PASS.secret` or --set `pgPass=...` setup postgres password for the default user (gha_admin).
- File `secrets/PG_PASS_RO.secret` or --set `pgPassRO=...` setup for the read-only user (ro_user).
- File `secrets/PG_PASS_TEAM.secret` or --set `pgPassTeam=...` setup the team user (also read-only) (devstats_team).
- File `secrets/PG_PASS_REP.secret` or --set `pgPassRep=...` setup the replication user.
- File `secrets/GHA2DB_GITHUB_OAUTH.secret` or --set `githubOAuth=...` setup GitHub OAuth token(s) (single value or comma separated list of tokens).
- File `secrets/GF_SECURITY_ADMIN_USER.secret` or --set `grafanaUser=...` setup Grafana admin user name.
- File `secrets/GF_SECURITY_ADMIN_PASSWORD.secret` or --set `grafanaPassword=...` setup Grafana admin user password.

You can select which secret(s) should be skipped via: `--set skipPGSecret=1,skipGitHubSecret=1,skipGrafanaSecret=1`.

You can install only selected templates, see `values.yaml` for detalis (refer to `skipXYZ` variables in comments), example:
- `helm install --dry-run --debug ./devstats-helm-example --set skipSecrets=1,skipPVs=1,skipBootstrap=1,skipProvisions=1,skipCrons=1,skipGrafanas=1,skipServices=1,skipPostgres=1,skipIngress=1`.

You can restrict ranges of projects provisioned and/or range of cron jobs to create via:
- `--set indexPVsFrom=5,indexPVsTo=9,indexProvisionsFrom=5,indexProvisionsTo=9,indexCronsFrom=5,indexCronsTo=9,indexGrafanasFrom=5,indexGrafanasTo=9,indexServicesFrom=5,indexServicesTo=9,indexIngressesFrom=5,indexIngressesTo=9`.

You can overwrite the number of CPUs autodetected in each pod, setting this to 1 will make each pod single-threaded
- `--set nCPUs=1`.

Please note variables commented out in `./devstats-helm-example/values.yaml`. You can either uncomment them or pass their values via `--set variable=name`.

Resource types used: secret, pv, pvc, po, cronjob, deployment, svc

To debug provisioning use:
- `helm install ./devstats-helm-example --set skipSecrets=1,skipPVs=1,skipBootstrap=1,skipCrons=1,skipGrafanas=1,skipServices=1,skipPostgres=1,skipIngress=1,indexProvisionsFrom=0,indexProvisionsTo=1,provisionCommand=sleep,provisionCommandArgs={36000s}`.
- `helm install --debug --dry-run ./devstats-helm-example --set skipSecrets=1,skipPVs=1,skipProvisions=1,skipCrons=1,skipGrafanas=1,skipServices=1,skipIngress=1,skipPostgres=1,bootstrapCommand=sleep,bootstrapCommandArgs={36000s}`
- Bash into it: `github.com/cncf/devstats-k8s-lf`: `./util/pod_shell.sh devstats-provision-cncf`.
- Then for example: `PG_USER=gha_admin db.sh psql cncf`, followed: `select dt, proj, prog, msg from gha_logs where proj = 'cncf' order by dt desc limit 40;`.
- Finally delete pod: `kubectl delete pod devstats-provision-cncf`.

# EKS cluster

If you want to use EKS cluster, there are some shell scripts in `scripts` directory that can be useful:

- `cncfekscluster.sh` - can be used to create EKS cluster, it uses [eksctl](https://eksctl.io).
- `cncfkubectl.sh` - once cluster is up and running you can use it as `kubectl` - it is configured to use cluster created by `cncfekscluster.sh`.
- `cncfec2desc.sh` - you can use it to list `EC2` instances created by `cncfekscluster.sh`.

Before using any of those script you need to define `cncf` AWS profile by modifying files in `~/.aws/` directory:

- `config` (example):
```
[profile cncf]
region = eu-west-3
output = json
```
- `credentials` (example redacted):
```
[cncf]
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
aws_access_key_id = yyyyyyyyyyyyyyyyyy
```

# Architecture

Final deployments:

- [CNCF](https://cncf.devstats-demo.net).
- [Prometheus](https://prometheus.devstats-demo.net).

DevStats data sources:

- GHA ([GitHub Archives](https://www.gharchive.org)) this is the main data source, it uses GitHub API in real-time and saves all events from every hour into big compressed files containing all events from that hour (JSON array).
- GitHub API (we're only using this to track issues/PRs hourly to make sure we're not missing wvents - GHA sometimes misses some events).
- git - we're storing closes for all GitHub repositories from all projects - that allows file-level granularity commits analysis.

Storage:

- All data from datasources are stored in HA Postgres database (patroni).
- Git repository clones are stored in per-pod persistent volumes (type AWS EBS). Each project has its own persisntent volume claim to store its git data.

Database:

- We are using patroni database consisting of 3 nodes. Each node has its own persistent volume claim (AWS EBS) that stores database data. This gives 3x redundancy.
- Docker limits each pod's shared memory to 64MB, so all patroni pods are mounting special volume (type: memory) under /dev/shm, that way each pod has unlimited SHM memory (actually limited by RAM accessible to pod).
- Patroni supports automatic master election (it uses ERBAC and manipulates service endpoints to make that transparent for app pods).
- Patroni is providing continuous replication within those 3 nodes.
- Write performance is limited by single node power, read performance is up to 3x (2 read replicas and master).

Cluster:

- We are using AWS EKS cluster running `v1.12` Kubernetes that is set up via [eksctl tool](https://eksctl.io).
- Currently we're using 3 EC2 nodes (type `m5.2xlarge`) in `us-east-1` zone.


https://prometheus.devstats-demo.net/d/8/dashboards?orgId=1 (full stack DevStats on EKS, using patroni HA database)
```Database: patroni with 3x redundancy (3 nodes). 1 master node (with automatic master elections) and 2 slave nodes/read replicas. Storage backend AWS EBS (3x redundancy). UI updated to Grafana 6.1.4. Using OpenShift hack that mounts volume type memory under /dev/shm (to avoid docker limiting pod SHM to 64MB which kills DB). Full Ingress stack is ready for CNCF EKS: this includes registered Route 53 domain pointing to nginx-ingress ELB external IP, AWS hosted zone, CNAME and Alias records (wildcard subdomains *.devstats-demo.net), cert-manager installation, production Let's encrypt SSL certificate with auto renewal + docs for all of this stuff - yay!```
still struggling with small provisioning issues, but you can see full-stack devstats deployed here: https://prometheus.devstats-demo.net and https://cncf.devstats-demo.net.
