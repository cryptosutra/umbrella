# Enterprise Data Platform - Umbrella Helm Chart

This project provides an umbrella Helm chart for deploying Apache Airflow, Apache Spark, and PostgreSQL on OpenShift as a unified data platform for enterprise tenants.

## Architecture

- **Apache Airflow 2.10**: Workflow orchestration with PostgreSQL metadata backend
- **Apache Spark 3.5**: Distributed computing with Kubernetes-native execution
- **PostgreSQL**: Metadata storage for Airflow and data persistence
- **OpenShift Compatible**: Designed for enterprise OpenShift deployments
- **Multi-tenant**: Support for custom tenant images from Nexus registry

## Components

### Airflow
- Web server and scheduler deployment
- PostgreSQL as metadata database
- DAG management with Spark job triggers
- Custom image support for tenant-specific workflows

### Spark
- Driver and executor pod templates
- Kubernetes-native execution mode
- Dynamic resource allocation
- Integration with Airflow for job orchestration

### PostgreSQL
- High-availability configuration
- Persistent storage for metadata
- OpenShift security context compatibility
- Backup and recovery support

## Quick Start

```bash
# Deploy with default values
helm install data-platform ./helm-charts/umbrella-chart

# Deploy with custom tenant configuration
helm install tenant-platform ./helm-charts/umbrella-chart -f tenant-values.yaml
```

## Directory Structure

```
helm-charts/
├── umbrella-chart/           # Main umbrella chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── charts/               # Sub-charts
│       ├── airflow/
│       ├── postgresql/
│       └── spark/
├── docs/                     # Documentation
└── examples/                 # Example configurations
```

## Customization

Each tenant can customize:
- Docker images from private Nexus registry
- Resource limits and requests
- Storage configurations
- Network policies
- Security contexts

See `examples/` directory for sample tenant configurations.
