# Enterprise Data Platform Deployment Guide

## Overview

This guide walks through deploying the Enterprise Data Platform umbrella Helm chart on OpenShift, which includes Apache Airflow, Apache Spark, and PostgreSQL.

## Prerequisites

1. **OpenShift Cluster**: Version 4.8 or higher
2. **Helm**: Version 3.8 or higher
3. **kubectl/oc CLI**: Configured to access your OpenShift cluster
4. **Storage**: Dynamic storage provisioning enabled
5. **Image Registry**: Access to Nexus or container registry with required images

## Required Images

Ensure the following images are available in your registry:

- PostgreSQL: `registry.redhat.io/rhel8/postgresql-13:latest`
- Apache Spark: `nexus.enterprise.com/spark:3.5.0`
- Apache Airflow: `nexus.enterprise.com/airflow:2.10.0`

## Installation Steps

### 1. Prepare Namespace

```bash
# Create namespace for the data platform
oc new-project data-platform

# Or using kubectl
kubectl create namespace data-platform
```

### 2. Configure Values

Create a tenant-specific values file:

```bash
cp examples/tenant-example-values.yaml my-tenant-values.yaml
# Edit the file with your tenant-specific configurations
```

Key configurations to customize:
- `global.tenant.name`: Your tenant identifier
- `global.imageRegistry.*`: Your Nexus/registry credentials
- Resource limits and requests
- Storage classes and sizes
- Network ingress settings

### 3. Deploy the Platform

```bash
# Install the umbrella chart
helm install my-data-platform ./helm-charts/umbrella-chart \
  -f my-tenant-values.yaml \
  --namespace data-platform \
  --create-namespace
```

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n data-platform

# Check services
kubectl get svc -n data-platform

# Check persistent volumes
kubectl get pvc -n data-platform
```

### 5. Access Airflow

```bash
# Port forward to access Airflow UI
kubectl port-forward svc/my-data-platform-airflow-webserver 8080:8080 -n data-platform

# Access at http://localhost:8080
# Default credentials: admin/admin
```

## Post-Deployment Configuration

### 1. Configure Spark Connection in Airflow

1. Access Airflow UI
2. Go to Admin > Connections
3. Create new connection:
   - Connection Id: `spark_k8s`
   - Connection Type: `Spark`
   - Host: `k8s://https://kubernetes.default.svc.cluster.local:443`
   - Extra: Configure Kubernetes-specific settings

### 2. Deploy Sample DAGs

```bash
# Copy sample DAG to DAGs volume
kubectl cp examples/sample-dag.py \
  my-data-platform-airflow-webserver-xxx:/opt/airflow/dags/ \
  -n data-platform
```

### 3. Test Spark Job Execution

1. Trigger the sample DAG from Airflow UI
2. Monitor Spark pods creation: `kubectl get pods -n data-platform -w`
3. Check Spark job logs and results

## Tenant Customization

### Custom Images

Update values file to point to your custom images:

```yaml
spark:
  image:
    registry: "nexus.your-company.com"
    repository: "your-tenant/spark-custom"
    tag: "3.5.0-custom-v1.0"

airflow:
  image:
    registry: "nexus.your-company.com"
    repository: "your-tenant/airflow-custom"
    tag: "2.10.0-custom-v1.0"
```

### Resource Scaling

Adjust resources based on workload:

```yaml
airflow:
  scheduler:
    replicas: 2
    resources:
      limits:
        memory: "2Gi"
        cpu: "1000m"
  webserver:
    replicas: 2
```

### Storage Configuration

Configure appropriate storage classes:

```yaml
global:
  storage:
    storageClass: "fast-ssd"

postgresql:
  primary:
    persistence:
      size: 100Gi
```

## Troubleshooting

### Common Issues

1. **Pods in Pending State**
   - Check resource quotas: `kubectl describe resourcequota -n data-platform`
   - Verify storage classes: `kubectl get storageclass`

2. **Image Pull Errors**
   - Verify registry credentials in values file
   - Check image pull secrets: `kubectl get secrets -n data-platform`

3. **Database Connection Issues**
   - Check PostgreSQL logs: `kubectl logs -l component=postgresql -n data-platform`
   - Verify service connectivity: `kubectl get svc -n data-platform`

4. **Spark Jobs Failing**
   - Check RBAC permissions for spark service accounts
   - Verify pod templates in ConfigMap
   - Check resource limits and node capacity

### Log Access

```bash
# Airflow scheduler logs
kubectl logs -l component=scheduler -n data-platform

# Airflow webserver logs
kubectl logs -l component=webserver -n data-platform

# PostgreSQL logs
kubectl logs -l app.kubernetes.io/name=postgresql -n data-platform

# Spark driver logs (during job execution)
kubectl logs -l spark-role=driver -n data-platform
```

## Maintenance

### Backup

1. **Database Backup**: Use PostgreSQL backup tools or volume snapshots
2. **DAGs Backup**: Backup DAGs volume or use git-sync for version control
3. **Configuration Backup**: Store Helm values files in version control

### Updates

```bash
# Update the deployment
helm upgrade my-data-platform ./helm-charts/umbrella-chart \
  -f my-tenant-values.yaml \
  --namespace data-platform
```

### Monitoring

Consider deploying monitoring stack:
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for alerting

## Security Considerations

1. **Network Policies**: Implement network policies to restrict inter-pod communication
2. **RBAC**: Review and minimize service account permissions
3. **Secrets Management**: Use external secret management systems
4. **Image Security**: Regularly scan custom images for vulnerabilities
5. **TLS**: Enable TLS for all external communications