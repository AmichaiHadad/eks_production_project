----------------
-"ApplicationSet name": app-
----------------

Deployed components: 
--------------------
- **ApplicationSet (`argocd/app-applicationset.yaml`):** Defines how the `app` workload is deployed using Argo CD. It uses a list generator to target the `eks-blizzard-us-east-1` cluster.
- **Helm Chart (`helm-chart/app`):** Deploys the Python web application (`app`).
    - `Deployment`: Manages the application pods.
    - `Service`: Exposes the application pods internally within the cluster (`ClusterIP`).
    - `Ingress`: Exposes the application service externally via an AWS ALB, configured with TLS using an ACM certificate. Hostname is dynamically generated based on the region.
    - `ExternalSecret` (app-weather-api-external-secret): Manages syncing the weather API key from AWS Secrets Manager to a Kubernetes secret (`app-secrets`). *Note: The template seems to target a secret named `app-secrets`, while the Helm values seem to expect `weather-api-key` and `mysql-app-credentials`. This might indicate a mismatch or reliance on ESO's default syncing behaviour.*
    - `ExternalSecret` (app-mysql-connection-eso-sync): Manages syncing MySQL credentials from AWS Secrets Manager to a Kubernetes secret (`mysql-app-creds`). *Note: Similar potential mismatch as above.*
    - `PodDisruptionBudget`: Ensures a minimum number of application pods are available during voluntary disruptions.
    - `ServiceMonitor`: Configures Prometheus scraping for the application's `/metrics` endpoint.
    - `PrometheusRule`: Defines alerting rules for high request rate, high error rate, slow response time, database errors, and weather API errors related to the application.

Hard coded vars:  
-----------------
- **ApplicationSet (`app-applicationset.yaml`):**
    - `metadata.name`: `app`
    - `spec.generators[0].list.elements[0].cluster`: `eks-blizzard-us-east-1`
    - `spec.generators[0].list.elements[0].url`: `https://kubernetes.default.svc`
    - `spec.generators[0].list.elements[0].acm_certificate_arn`: `arn:aws:acm:us-east-1:163459217187:certificate/4ff90f30-64f8-40e1-b1b3-8f13d5fac876`
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_production_project.git`
    - `spec.template.spec.source.path`: `helm-chart/app`
    - `spec.template.spec.source.targetRevision`: `main`
    - `spec.template.spec.source.helm.valueFiles`: `[values.yaml]`
    - Helm Parameter Overrides (e.g., `image.repository`, `ingress.hosts[0].host`, `secrets.*`, `db.serviceName`, etc.) - dynamically generated based on generator elements.
    - `spec.template.spec.destination.namespace`: `app`
    - `spec.template.spec.syncPolicy`: `automated: {prune: true, selfHeal: true}, syncOptions: [CreateNamespace=true]`
- **Helm Chart (`helm-chart/app`):**
    - Default values in `values.yaml` (e.g., `replicaCount: 2`, `image.pullPolicy: Always`, `service.type: ClusterIP`, `service.port: 80`, `service.targetPort: 5000`, `ingress.className: alb`, default annotations, `env` variables like `WELCOME_MESSAGE`, default probe settings, PDB settings, resource requests/limits).
    - Ingress Path: `/` (`templates/ingress.yaml`)
    - ExternalDNS TTL: `300` (`templates/ingress.yaml`)
    - `ServiceMonitor` Path: `/metrics` (`templates/servicemonitor.yaml`)
    - PrometheusRule expressions and durations (`templates/prometheusrule.yaml`).
    - `ExternalSecret` refreshInterval: `1h` (`templates/secrets.yaml`)
    - `ExternalSecret` secretStoreRef: `name: aws-secretsmanager, kind: ClusterSecretStore` (`templates/secrets.yaml`)
    - `ExternalSecret` target creationPolicy: `Owner` (`templates/secrets.yaml`)
    - `ExternalSecret` target names: `app-secrets`, `mysql-app-creds` (`templates/secrets.yaml`) - *Note potential mismatch with Deployment env vars.*

Required env vars:
-------------------
- None explicitly required by the ApplicationSet or Helm chart itself, but relies on secrets managed by the `external-secrets` Terraform module which sources its values potentially from `TF_VAR_weather_api_key`.

Inputs: 
-------
- **ApplicationSet (`app-applicationset.yaml`):**
    - Generator `elements`: Provides `name`, `cluster`, `url`, `region`, `acm_certificate_arn`. Used to dynamically set Helm parameters.
- **Helm Chart (`helm-chart/app/values.yaml` overrides from ApplicationSet):**
    - `image.repository`: Generated from `elements.region`.
    - `ingress.hosts[0].host`: Generated from `elements.region`.
    - `region`: From `elements.region`.
    - `ingress.acmCertificateArn`: From `elements.acm_certificate_arn`.
    - `secrets.weatherApiKeySecretName`: Hardcoded in AppSet template (`weather-api-key`).
    - `secrets.weatherApiKeySecretKey`: Hardcoded in AppSet template (`api-key`).
    - `secrets.mysqlCredsSecretName`: Hardcoded in AppSet template (`mysql-app-credentials`).
    - `secrets.mysqlPasswordSecretKey`: Hardcoded in AppSet template (`password`).
    - `secrets.mysqlUsernameSecretKey`: Hardcoded in AppSet template (`username`).
    - `secrets.mysqlDatabaseSecretKey`: Hardcoded in AppSet template (`database`).
    - `db.serviceName`: Generated from `elements.cluster` (`mysql-{{cluster}}`).
    - `db.namespace`: Hardcoded in AppSet template (`data`).
- **Helm Chart (`helm-chart/app/values.yaml` defaults):**
    - `replicaCount`, `image.tag`, `image.pullPolicy`, `nodeSelector`, `securityContext`, `containerSecurityContext`, `service`, `ingress` (defaults & static annotations), `env`, `podDisruptionBudget`, `podAnnotations`, `serviceMonitor`, `prometheusRule`, probes, `secrets` (structure, specific names/keys overridden by AppSet).

Outputs:
--------
- None defined for this ApplicationSet/Helm chart.

Versioning: 
-----------
- Helm Chart (`helm-chart/app/Chart.yaml`): `version: 0.1.0`, `appVersion: 1.0.0`

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Helm (used by Argo CD to render the chart)
- External Secrets Operator (to resolve ExternalSecrets created by the chart)

----------------
-"ApplicationSet name": monitoring-
----------------

Deployed components: 
--------------------
- **ApplicationSet (`argocd/monitoring-applicationset.yaml`):** Defines how the monitoring stack is deployed using Argo CD. Targets the `eks-blizzard-us-east-1` cluster. Passes secret names (for Slack) obtained from Terraform outputs to the Helm chart.
- **Helm Chart (`helm-chart/monitoring`):** Deploys the monitoring stack using upstream community charts as dependencies.
    - `kube-prometheus-stack` (Dependency): Deploys Prometheus, Grafana, Alertmanager, Prometheus Operator, node-exporter, kube-state-metrics.
        - **Grafana:** Configured to run on 'monitoring' nodes, uses an existing secret (`grafana-admin-credentials`) for admin credentials, has persistence enabled, and includes Elasticsearch as an additional datasource. Default dashboards are disabled. Custom dashboards are added via ConfigMaps. An Ingress is created via a separate template (`templates/grafana-ingress.yaml`) using ALB and ExternalDNS.
        - **Prometheus:** Runs on 'monitoring' nodes, configured with persistence, and includes additional scrape configs for MySQL and Elasticsearch exporters, and KEDA metrics API server. Uses CRDs for rule/monitor discovery.
        - **Alertmanager:** Runs on 'monitoring' nodes, configured with persistence. Uses an `AlertmanagerConfig` CRD (`templates/alertmanager-config.yaml`) for Slack notifications, referencing the `alertmanager-slack-webhook` secret.
        - **Node Exporter & Kube State Metrics:** Run on monitoring nodes with appropriate tolerations.
    - `prometheus-mysql-exporter` (Dependency): Deploys the MySQL exporter, configured to connect to the internal MySQL service. Runs on monitoring nodes. A `ServiceMonitor` is enabled.
    - `prometheus-elasticsearch-exporter` (Dependency): Deploys the Elasticsearch exporter, configured to connect to the internal Elasticsearch service. Runs on monitoring nodes. A `ServiceMonitor` is enabled.
    - `AlertmanagerConfig` (`templates/alertmanager-config.yaml`): Configures Alertmanager routing and a Slack receiver, referencing the `alertmanager-slack-webhook` Kubernetes secret.
    - `PrometheusRule` (`templates/prometheus-rules.yaml`): Defines custom alerting rules for MySQL, Elasticsearch, the application (`app.rules`), Karpenter, and Nodes.
    - `ConfigMap`s (`templates/grafana-dashboards.yaml`): Provides custom Grafana dashboard JSON for Kubernetes, MySQL, and Elasticsearch, mounted via the sidecar.
    - `Ingress` (`templates/grafana-ingress.yaml`): Configures external access to Grafana via ALB, using ExternalDNS and an ACM certificate defined in the Helm values.

Hard coded vars:  
-----------------
- **ApplicationSet (`monitoring-applicationset.yaml`):**
    - `metadata.name`: `monitoring`
    - `spec.generators[0].list.elements[0].cluster`: `eks-blizzard-us-east-1`
    - `spec.generators[0].list.elements[0].url`: `https://kubernetes.default.svc`
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_production_project.git`
    - `spec.template.spec.source.path`: `helm-chart/monitoring`
    - `spec.template.spec.source.targetRevision`: `main`
    - `spec.template.spec.source.helm.valueFiles`: `[values.yaml]`
    - Helm Parameter Overrides (e.g., disabling `externalDns`, setting `clusterName`, passing secret names, Grafana existingSecret config, `skipCrds: true`).
    - `spec.template.spec.destination.namespace`: `monitoring`
    - `spec.template.spec.syncPolicy`: `automated: {prune: true, selfHeal: true}, syncOptions: [CreateNamespace=true, ServerSideApply=true, ApplyOutOfSyncOnly=true, Replace=false, SkipDryRunOnMissingResource=true]`
- **Helm Chart (`helm-chart/monitoring`):**
    - Default values in `values.yaml` (e.g., enabling components, nodeSelectors/tolerations for 'monitoring' role, resource requests/limits, persistence settings, default Alertmanager config, default Prometheus rules enabled).
    - Grafana `additionalDataSources` for Elasticsearch (`templates/values.yaml`).
    - `prometheus-mysql-exporter` config: `host: mysql.data`, `port: 3306`, `user: prometheus`, `db: app_db` (`values.yaml`). *Note: Password placeholder relies on ESO/Secret.*
    - `prometheus-elasticsearch-exporter` config: `es.uri: http://elasticsearch.data.svc.cluster.local:9200` (`values.yaml`).
    - `AlertmanagerConfig` receiver name (`slack-receiver`), channel (`#alerts`), secret key (`slack_webhook_url`), secret name (`alertmanager-slack-webhook`) (`templates/alertmanager-config.yaml`).
    - `PrometheusRule` expressions, durations, severities (`templates/prometheus-rules.yaml`).
    - `ConfigMap` names and dashboard JSON content (`templates/grafana-dashboards.yaml`).
    - `Ingress` annotations for ALB, ExternalDNS hostname pattern (`grafana-{{ .Values.global.region }}.blizzard.co.il`), ExternalDNS owner ID (`eks-blizzard-us-east-1`), backend service name pattern (`{{ printf "%s-grafana" .Release.Name }}`) (`templates/grafana-ingress.yaml`).

Required env vars:
-------------------
- None explicitly required by the ApplicationSet or Helm chart itself, but relies on secrets managed by the `external-secrets` Terraform module (Grafana admin, Slack webhook).

Inputs: 
-------
- **ApplicationSet (`monitoring-applicationset.yaml`):**
    - Generator `elements`: Provides `name`, `cluster`, `url`, `region`, `slack_webhook_secret_name`.
    - `slack_webhook_secret_name`: Value comes from `dependency.external_secrets.outputs.slack_webhook_secret_name` in `terragrunt/us-east-1/argocd/terragrunt.hcl`.
- **Helm Chart (`helm-chart/monitoring/values.yaml` overrides from ApplicationSet):**
    - `clusterName`: Generated from `elements.region` (`eks-blizzard-{{region}}`).
    - `global.region`: From `elements.region`.
    - `slackWebhookSecretName`: From `elements.slack_webhook_secret_name`.
    - `kube-prometheus-stack.grafana.admin.existingSecret`: Hardcoded in AppSet template (`grafana-admin-credentials`). *Note: Assumes this secret is created by the `external-secrets` module.*
    - `kube-prometheus-stack.grafana.admin.userKey`: Hardcoded in AppSet template (`admin-user`).
    - `kube-prometheus-stack.grafana.admin.passwordKey`: Hardcoded in AppSet template (`admin-password`).
- **Helm Chart (`helm-chart/monitoring/values.yaml` defaults & internal logic):**
    - Most configuration for `kube-prometheus-stack`, `prometheus-mysql-exporter`, `prometheus-elasticsearch-exporter` comes from defaults within `values.yaml`.
    - Grafana Ingress hostname generated using `global.region`.
    - Alertmanager config uses `alertmanager-slack-webhook` secret by name (expected to exist).

Outputs:
--------
- None defined for this ApplicationSet/Helm chart.

Versioning: 
-----------
- Helm Chart (`helm-chart/monitoring/Chart.yaml`): `version: 0.1.0`, `appVersion: 1.0.0`
- Dependencies:
    - `kube-prometheus-stack`: `51.4.0`
    - `prometheus-mysql-exporter`: `1.14.0`
    - `prometheus-elasticsearch-exporter`: `5.2.0`

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Helm (used by Argo CD to render the chart and its dependencies)

----------------
-"ApplicationSet name": mysql-
----------------

Deployed components: 
--------------------
- **ApplicationSet (`argocd/mysql-applicationset.yaml`):** Defines how MySQL is deployed using Argo CD. Targets the `eks-blizzard-us-east-1` cluster.
- **Helm Chart (`helm-chart/mysql`):** Deploys MySQL using the Bitnami MySQL chart as a dependency.
    - `mysql` (Dependency - Bitnami Chart): Deploys MySQL as a `StatefulSet` (`architecture: standalone`).
        - **StatefulSet:** Manages the MySQL pod(s). Configured to run on 'data' nodes, uses persistence (PVC template defined with gp3 storage class), and has specific resource requests/limits. Uses the `mysql-sa` service account created by the `security-policies` Terraform module. Environment variables (`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`) are sourced from Kubernetes secrets (`mysql-root-credential`, `mysql-app-credential`) which are expected to be created by the `external-secrets` Terraform module.
        - **Service (`ClusterIP`):** Exposes MySQL internally.
        - **Secrets:** The Bitnami chart manages its own internal secrets if external ones aren't correctly referenced/available. *Note: The current `values.yaml` configuration relies on environment variables sourced from secrets created externally (by Terraform), effectively overriding the Bitnami chart's default secret handling.*

Hard coded vars:  
-----------------
- **ApplicationSet (`mysql-applicationset.yaml`):**
    - `metadata.name`: `mysql`
    - `spec.generators[0].list.elements[0].cluster`: `eks-blizzard-us-east-1`
    - `spec.generators[0].list.elements[0].url`: `https://kubernetes.default.svc`
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_production_project.git`
    - `spec.template.spec.source.path`: `helm-chart/mysql`
    - `spec.template.spec.source.targetRevision`: `HEAD`
    - Helm `values` block: Sets `global.storageClass`, `auth.createDatabase`, `auth.database`, `auth.username`, primary persistence, serviceAccount settings, defines `extraEnvVars` sourcing passwords from specific K8s secrets (`mysql-root-credential`, `mysql-app-credential`). Disables replication and secondary nodes.
    - `spec.template.spec.destination.namespace`: `data`
    - `spec.template.spec.syncPolicy`: `automated: {prune: true, selfHeal: true}, syncOptions: [CreateNamespace=true, ServerSideApply=true]`
- **Helm Chart (`helm-chart/mysql`):**
    - Default values overridden by ApplicationSet `values` block. Key defaults include `architecture: standalone`, persistence enabled, resource requests/limits, service type/port, security context settings (`values.yaml`).
    - Dependency on Bitnami MySQL chart (`Chart.yaml`).

Required env vars:
-------------------
- None explicitly required by the ApplicationSet or Helm chart itself, but relies on Kubernetes secrets (`mysql-root-credential`, `mysql-app-credential`) which are created and populated by the `external-secrets` Terraform module.

Inputs: 
-------
- **ApplicationSet (`mysql-applicationset.yaml`):**
    - Generator `elements`: Provides `cluster`, `region`, `url`. Used in template metadata name and destination server.
- **Helm Chart (`helm-chart/mysql/values.yaml` overrides from ApplicationSet):**
    - `global.storageClass`: `"gp2"`
    - `auth.createDatabase`: `true`
    - `auth.database`: `"app_db"`
    - `auth.username`: `"app_user"`
    - `primary.persistence.enabled`: `true`
    - `primary.persistence.size`: `8Gi`
    - `primary.serviceAccount.create`: `false`
    - `primary.serviceAccount.name`: `"mysql-sa"`
    - `primary.extraEnvVars`: Defines `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` sourcing from specific K8s secrets.
    - `secondary.replicaCount`: `0`
    - `replication.enabled`: `false`
- **Helm Chart (`helm-chart/mysql/values.yaml` defaults):**
    - `architecture`, `primary.nodeSelector` (`node-role: data`), `primary.tolerations` (for data role), `primary.resources`, `service`, `securityContext`.

Outputs:
--------
- None defined for this ApplicationSet/Helm chart.

Versioning: 
-----------
- Helm Chart (`helm-chart/mysql/Chart.yaml`): `version: 0.1.0`, `appVersion: 8.0.32`
- Dependency (`helm-chart/mysql/Chart.lock`): `mysql` (Bitnami) version `12.2.4`

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Helm (used by Argo CD to render the chart and its dependency)

----------------
-"ApplicationSet name": elasticsearch-service-
----------------

Deployed components: 
--------------------
- **ApplicationSet (`argocd/elasticsearch-applicationset.yaml`):** Defines how Elasticsearch is deployed using Argo CD. Uses a list generator targeting the default cluster URL.
- **Helm Chart (`helm-chart/elasticsearch`):** Deploys Elasticsearch using the official Docker image.
    - `ConfigMap` (elasticsearch-config): Contains `elasticsearch.yml` configuration, including cluster name, node name (from HOSTNAME env var), paths, memory settings, network host, index settings, discovery settings (single-node or multi-node based on `values.discovery`), and node roles. Security is disabled.
    - `Service` (elasticsearch): `ClusterIP` service exposing HTTP port 9200 and transport port 9300.
    - `Service` (elasticsearch-headless): Headless service for StatefulSet discovery, exposing port 9300.
    - `StatefulSet` (elasticsearch): Manages the Elasticsearch pods.
        - Configured with replicas based on `values.replicas`.
        - Uses topology spread constraints for zone distribution.
        - Includes init containers to fix data directory permissions and set `vm.max_map_count`.
        - Mounts the ConfigMap and uses a PVC template (`data`) for persistent storage.
        - Configures environment variables (`ES_JAVA_OPTS`, security disabled, etc.), resource requests/limits, probes, node selector ('data' role), and tolerations ('data' role).
    - `Job` (elasticsearch-setup-ilm): A post-install/post-upgrade Helm hook Job that waits for the Elasticsearch cluster to be ready (yellow or green status) and then configures an Index Lifecycle Management (ILM) policy (`logs-policy`) for log rotation (rollover after 7d/10gb, warm after 30d, delete after 90d), an index template (`logs-template`) applying the policy to `k8s-logs-*` indices, and creates the initial index (`k8s-logs-000001`) with the rollover alias (`k8s-logs`).

Hard coded vars:  
-----------------
- **ApplicationSet (`elasticsearch-applicationset.yaml`):**
    - `metadata.name`: `elasticsearch-service`
    - `spec.generators[0].list.elements[0].name`: `elasticsearch`
    - `spec.generators[0].list.elements[0].namespace`: `data`
    - `spec.generators[0].list.elements[0].server`: `https://kubernetes.default.svc`
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_production_project.git`
    - `spec.template.spec.source.path`: `helm-chart/{{name}}` (becomes `helm-chart/elasticsearch`)
    - `spec.template.spec.source.targetRevision`: `main`
    - Helm `values` overrides: `replicas: "3"`, `discovery: "multi-node"`
    - `spec.template.spec.destination.server`: `{{server}}` (becomes `https://kubernetes.default.svc`)
    - `spec.template.spec.destination.namespace`: `{{namespace}}` (becomes `data`)
    - `spec.template.spec.syncPolicy`: `automated: {prune: true, selfHeal: true}, syncOptions: [CreateNamespace=true]`
- **Helm Chart (`helm-chart/elasticsearch`):**
    - ConfigMap `elasticsearch.yml` content: cluster name (`logging-cluster`), paths, memory settings, network host (`0.0.0.0`), discovery hosts (`elasticsearch-headless...`), initial master nodes (`elasticsearch-0`, etc.), node roles (`master`, `data`), security disabled (`false`), publish host pattern (`${HOSTNAME}.elasticsearch-headless...`). (`templates/elasticsearch.yaml`)
    - Headless service name (`elasticsearch-headless`), ClusterIP service name (`elasticsearch`). Ports 9200 (http), 9300 (transport). (`templates/elasticsearch.yaml`)
    - StatefulSet init container images (`busybox:1.35.0`), commands (`chown`, `sysctl`). (`templates/elasticsearch.yaml`)
    - StatefulSet env vars: `ES_JAVA_OPTS: "-Xms2g -Xmx2g"`. (`templates/elasticsearch.yaml`)
    - StatefulSet readiness/liveness probe paths (`/_cluster/health?local=true`), ports (9200), timings. (`templates/elasticsearch.yaml`)
    - Default values in `values.yaml` (image repo/tag, resources, storage class/size, nodeSelector/tolerations for 'data' role, security disabled, service type/port).
    - ILM Job image (`curlimages/curl:7.86.0`), wait logic (`curl -s http://elasticsearch:9200/_cluster/health`), ILM policy JSON (`logs-policy`), Index Template JSON (`logs-template`), initial index name (`k8s-logs-000001`), rollover alias (`k8s-logs`). (`templates/elasticsearch.yaml`)

Required env vars:
-------------------
- None explicitly required by the ApplicationSet or Helm chart itself.

Inputs: 
-------
- **ApplicationSet (`elasticsearch-applicationset.yaml`):**
    - Generator `elements`: Provides `name`, `namespace`, `server`.
    - Helm `values`: `replicas: "3"`, `discovery: "multi-node"`.
- **Helm Chart (`helm-chart/elasticsearch/values.yaml` overrides from ApplicationSet):**
    - `.Values.replicas`: `"3"`
    - `.Values.discovery`: `"multi-node"`
- **Helm Chart (`helm-chart/elasticsearch/values.yaml` defaults):**
    - `image.repository`, `image.tag`, `resources`, `storage`, `security.enabled`, `nodeSelector`, `tolerations`, `service`.

Outputs:
--------
- None defined for this ApplicationSet/Helm chart.

Versioning: 
-----------
- Helm Chart (`helm-chart/elasticsearch/Chart.yaml`): `version: 0.1.0`, `appVersion: 8.10.4`
- Elasticsearch Image (`values.yaml`): `docker.elastic.co/elasticsearch/elasticsearch:8.10.4`

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Helm (used by Argo CD to render the chart)

----------------
-"ApplicationSet name": fluentd-service-
----------------

Deployed components: 
--------------------
- **ApplicationSet (`argocd/fluentd-applicationset.yaml`):** Defines how Fluentd is deployed using Argo CD. Uses a list generator targeting the default cluster URL and the `logging` namespace.
- **Helm Chart (`helm-chart/fluentd`):** Deploys Fluentd using the Bitnami Fluentd chart as a dependency.
    - `fluentd` (Dependency - Bitnami Chart): Deploys Fluentd, likely as a `DaemonSet` based on the `values.yaml` structure (`forwarder.daemonset.enabled: true`).
        - **DaemonSet:** Runs Fluentd pods on all nodes (or nodes matching selector if specified, but none is). Tolerates all taints (`operator: Exists`).
        - **ConfigMap (`fluentd-forwarder`):** Created via the Helm template (`templates/configmap.yaml`), contains the Fluentd configuration (`fluentd.conf`) defined in `values.yaml`. This config defines input sources (HTTP healthcheck, container logs), filters (Kubernetes metadata, error detection), and an Elasticsearch output configured via environment variables.
        - **ServiceAccount & RBAC:** Creates necessary permissions for Fluentd to read logs and Kubernetes metadata (managed by Bitnami chart defaults).
        - **Environment Variables:** Sets `ELASTICSEARCH_HOST`, `PORT`, `SCHEME` based on values provided in the Helm values (overridden by ApplicationSet in this case, pointing to the internal Elasticsearch service).

Hard coded vars:  
-----------------
- **ApplicationSet (`fluentd-applicationset.yaml`):**
    - `metadata.name`: `fluentd-service`
    - `spec.generators[0].list.elements[0].name`: `fluentd`
    - `spec.generators[0].list.elements[0].namespace`: `logging`
    - `spec.generators[0].list.elements[0].server`: `https://kubernetes.default.svc`
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_production_project.git`
    - `spec.template.spec.source.path`: `helm-chart/{{name}}` (becomes `helm-chart/fluentd`)
    - `spec.template.spec.source.targetRevision`: `main`
    - `spec.template.spec.destination.server`: `{{server}}` (becomes `https://kubernetes.default.svc`)
    - `spec.template.spec.destination.namespace`: `{{namespace}}` (becomes `logging`)
    - `spec.template.spec.syncPolicy`: `automated: {prune: true, selfHeal: true}, syncOptions: [CreateNamespace=true]`
- **Helm Chart (`helm-chart/fluentd`):**
    - ConfigMap name: `fluentd-forwarder` (`templates/configmap.yaml`)
    - `fluentd.conf` content defined in `values.yaml`: sources (`@type http`, `@type tail` for `/var/log/containers/*.log`), filters (`@type kubernetes_metadata`, `@type grep` for errors), match (`@type elasticsearch`), Elasticsearch connection details use ENV vars, buffer configuration. (`values.yaml`)
    - `forwarder.enabled: true`, `forwarder.daemonset.enabled: true`, `forwarder.configMap: fluentd-forwarder`. (`values.yaml`)
    - `forwarder.extraEnvVars`: Defines `FLUENTD_CONF`, `ELASTICSEARCH_HOST`, `PORT`, `SCHEME`. (`values.yaml`)
    - `forwarder.tolerations`: `[{operator: Exists}]` (`values.yaml`).
    - `aggregator.enabled: false`. (`values.yaml`)
    - Default resources, RBAC settings (`values.yaml`).

Required env vars:
-------------------
- None explicitly required by the ApplicationSet or Helm chart itself. Fluentd container uses env vars (`ELASTICSEARCH_HOST`, etc.) set directly within the Helm values.

Inputs: 
-------
- **ApplicationSet (`fluentd-applicationset.yaml`):**
    - Generator `elements`: Provides `name`, `namespace`, `server`.
- **Helm Chart (`helm-chart/fluentd/values.yaml` overrides from ApplicationSet):**
    - None explicitly overridden by this ApplicationSet.
- **Helm Chart (`helm-chart/fluentd/values.yaml` defaults):**
    - All configuration is driven by the defaults within the `values.yaml` file, including the entire `fluentd.conf` content, daemonset settings, resources, RBAC, etc.

Outputs:
--------
- None defined for this ApplicationSet/Helm chart.

Versioning: 
-----------
- Helm Chart (`helm-chart/fluentd/Chart.yaml`): `version: 0.1.0`, `appVersion: v1.16.1`
- Dependency: `fluentd` (Bitnami) version `5.8.7`

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Helm (used by Argo CD to render the chart and its dependency)

----------------
-"ApplicationSet name": crds-
----------------

*Note: This ApplicationSet (`crd-applicationset.yaml`) is present in the `argocd/` directory but not explicitly referenced in the `terragrunt/us-east-1/argocd/terragrunt.hcl` configuration's `application_sets` list. It might be managed separately or be a remnant.*

Deployed components: 
--------------------
- **ApplicationSet (`argocd/crd-applicationset.yaml`):** Defines deployment of Kubernetes Custom Resource Definitions (CRDs) using Argo CD. Uses a list generator targeting the `eks-blizzard-us-east-1` cluster.
- **Raw Manifests (`crd-manifests/all-crds/`):** Contains YAML definitions for various CRDs required by other components (e.g., `monitoring.coreos.com`, `karpenter.sh`, `aquasecurity.github.io`, `external-secrets.io`, etc.). The ApplicationSet applies all manifests found in this directory.

Hard coded vars:  
-----------------
- **ApplicationSet (`crd-applicationset.yaml`):**
    - `metadata.name`: `crds`
    - `spec.generators[0].list.elements[0].cluster`: `eks-blizzard-us-east-1`
    - `spec.generators[0].list.elements[0].url`: `https://kubernetes.default.svc`
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_production_project.git`
    - `spec.template.spec.source.path`: `crd-manifests/all-crds`
    - `spec.template.spec.source.targetRevision`: `main`
    - `spec.template.spec.destination.server`: `{{url}}` (becomes `https://kubernetes.default.svc`)
    - `spec.template.spec.destination.namespace`: `kube-system`
    - `spec.template.spec.syncPolicy`: `automated: {prune: false, selfHeal: true}, syncOptions: [CreateNamespace=false, ApplyOutOfSyncOnly=true, ServerSideApply=true, SkipHelmHooks=true, Replace=false]`
- **Raw Manifests (`crd-manifests/all-crds/`):**
    - All CRD definitions themselves.

Required env vars:
-------------------
- None identified.

Inputs: 
-------
- **ApplicationSet (`crd-applicationset.yaml`):**
    - Generator `elements`: Provides `name`, `cluster`, `url`.

Outputs:
--------
- None defined.

Versioning: 
-----------
- CRD versions are defined within each individual YAML file in the `crd-manifests/all-crds/` directory.

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Kubernetes API (directly applies raw manifests)

----------------
-"ApplicationSet name": stateful-services- (OBSOLETE?)
----------------

*Note: This ApplicationSet (`stateful-applicationset.yaml`) is present in the `argocd/` directory but not explicitly referenced in the `terragrunt/us-east-1/argocd/terragrunt.hcl` configuration's `application_sets` list. It appears to be an older approach, as individual ApplicationSets exist for mysql, elasticsearch, and fluentd.*

Deployed components: 
--------------------
- **ApplicationSet (`argocd/stateful-applicationset.yaml`):** Defines deployment of multiple stateful services (MySQL, Elasticsearch, Fluentd) using a single ApplicationSet with a list generator.
- **Helm Charts (`helm-chart/mysql`, `helm-chart/elasticsearch`, `helm-chart/fluentd`):** Deploys the respective services based on the generator elements.

Hard coded vars:  
-----------------
- **ApplicationSet (`stateful-applicationset.yaml`):**
    - `metadata.name`: `stateful-services`
    - `spec.generators[0].list.elements`: Contains entries for `mysql`, `elasticsearch`, `fluentd` specifying `namespace`, `server`, and specific `values` (like secret names, replicas).
    - `spec.template.spec.source.repoURL`: `https://github.com/AmichaiHadad/eks_app_2.git`
    - `spec.template.spec.source.targetRevision`: `main`
    - `spec.template.spec.source.path`: `helm-chart/{{name}}` (dynamically selects chart)
    - Helm `parameters`: Uses `{{values...}}` to pass values from the generator elements.
    - `spec.template.spec.destination.server`: `{{server}}`
    - `spec.template.spec.destination.namespace`: `{{namespace}}`
    - `spec.template.spec.syncPolicy`: `automated: {prune: true, selfHeal: true}, syncOptions: [CreateNamespace=true]`

Required env vars:
-------------------
- None identified.

Inputs: 
-------
- **ApplicationSet (`stateful-applicationset.yaml`):**
    - Generator `elements`: Provides `name`, `namespace`, `server`, and specific `values` for each service.

Outputs:
--------
- None defined.

Versioning: 
-----------
- Helm Chart versions are defined in the respective `Chart.yaml` files within `helm-chart/mysql`, `helm-chart/elasticsearch`, `helm-chart/fluentd`.

Providers/Required Providers:
------------------------------
- Argo CD (manages ApplicationSet and Application deployment)
- Helm (used by Argo CD to render the charts)

</rewritten_file> 