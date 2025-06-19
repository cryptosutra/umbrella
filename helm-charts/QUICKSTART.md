# Quick Start Guide

## Overview
This umbrella Helm chart deploys Apache Airflow 2.10, Apache Spark 3.5, and PostgreSQL as an integrated data platform on OpenShift.

## Prerequisites
- OpenShift 4.8+ or Kubernetes 1.20+
- Helm 3.8+
- Storage with dynamic provisioning
- Access to container registry (Nexus)

## Quick Deployment

### 1. Basic Installation
```bash
# Deploy with default settings
helm install data-platform ./helm-charts/umbrella-chart \
  --create-namespace \
  --namespace data-platform
```

### 2. Production Installation
```bash
# Deploy with production configuration
helm install prod-platform ./helm-charts/umbrella-chart \
  -f examples/production-values.yaml \
  --create-namespace \
  --namespace data-platform-prod
```

### 3. Tenant-Specific Installation
```bash
# Deploy with tenant customization
helm install tenant-platform ./helm-charts/umbrella-chart \
  -f examples/tenant-example-values.yaml \
  --create-namespace \
  --namespace tenant-data-platform
```

## Validation

### Automated Validation
```bash
# Run validation script
./helm-charts/validate-deployment.sh data-platform data-platform

# Expected output: All validations passed!
```

### Manual Validation
```bash
# Check pod status
kubectl get pods -n data-platform

# Access Airflow UI
kubectl port-forward svc/data-platform-airflow-webserver 8080:8080 -n data-platform
# Visit: http://localhost:8080 (admin/admin)

# Check database connectivity
kubectl run -it --rm db-test --image=postgres:13 -n data-platform -- \
  psql -h data-platform-postgresql -U airflow -d airflow
```

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              data-platform namespace              │  │
│  │                                                      │  │
│  │  ┌──────────────┐    ┌──────────────┐               │  │
│  │  │   Airflow    │    │ PostgreSQL   │               │  │
│  │  │              │───▶│              │               │  │
│  │  │ • Webserver  │    │ • Metadata   │               │  │
│  │  │ • Scheduler  │    │ • Persistence│               │  │
│  │  └──────────────┘    └──────────────┘               │  │
│  │          │                                           │  │
│  │          ▼                                           │  │
│  │  ┌──────────────┐    ┌──────────────┐               │  │
│  │  │    Spark     │    │   Storage    │               │  │
│  │  │              │    │              │               │  │
│  │  │ • Driver     │    │ • DAGs PVC   │               │  │
│  │  │ • Executors  │    │ • Logs PVC   │               │  │
│  │  │ • Dynamic    │    │ • DB PVC     │               │  │
│  │  └──────────────┘    └──────────────┘               │  │
│  └───────────────────────────────────────────────────────┐  │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

✅ **Multi-tenant ready** - Custom images per tenant  
✅ **OpenShift compatible** - Security contexts and RBAC  
✅ **Production ready** - HA configurations available  
✅ **Spark integration** - Kubernetes-native Spark execution  
✅ **Persistent storage** - Data and metadata persistence  
✅ **Monitoring ready** - Prometheus/Grafana integration  
✅ **Auto-scaling** - Dynamic Spark executor scaling  

## Next Steps

1. **Customize Configuration**: Edit `values.yaml` for your environment
2. **Deploy DAGs**: Add your workflow definitions
3. **Configure Connections**: Set up data source connections in Airflow
4. **Monitor**: Set up monitoring and alerting
5. **Scale**: Adjust resources based on workload requirements

## Support

- **Documentation**: See `docs/` directory for detailed guides
- **Examples**: Check `examples/` for configuration templates
- **Troubleshooting**: Use `docs/troubleshooting.md` for common issues
- **Validation**: Run `validate-deployment.sh` after deployment