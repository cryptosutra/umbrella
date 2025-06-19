# Troubleshooting Guide

## Common Issues and Solutions

### 1. Pod Startup Issues

#### Pods Stuck in Pending State

**Symptoms:**
```bash
kubectl get pods -n data-platform
NAME                                     READY   STATUS    RESTARTS   AGE
airflow-scheduler-xxx-xxx               0/1     Pending   0          5m
```

**Possible Causes & Solutions:**

1. **Insufficient Resources**
   ```bash
   # Check resource quotas
   kubectl describe resourcequota -n data-platform
   
   # Check node resources
   kubectl describe nodes | grep -A 5 "Allocated resources"
   
   # Solution: Adjust resource requests or add more nodes
   ```

2. **Storage Issues**
   ```bash
   # Check PVC status
   kubectl get pvc -n data-platform
   
   # Check storage classes
   kubectl get storageclass
   
   # Solution: Verify storage class exists and has available capacity
   ```

3. **Node Selector/Affinity Issues**
   ```bash
   # Check node labels
   kubectl get nodes --show-labels
   
   # Solution: Ensure nodes have required labels or remove node selectors
   ```

#### Pods in CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n data-platform
NAME                                     READY   STATUS             RESTARTS   AGE
postgresql-0                            0/1     CrashLoopBackOff   5          10m
```

**Diagnosis & Solutions:**

1. **Check Pod Logs**
   ```bash
   kubectl logs postgresql-0 -n data-platform
   kubectl logs postgresql-0 -n data-platform --previous
   ```

2. **Common PostgreSQL Issues**
   ```bash
   # Permission issues
   # Check if volumes have correct ownership
   kubectl exec -it postgresql-0 -n data-platform -- ls -la /var/lib/pgsql/data
   
   # Solution: Ensure securityContext is properly configured
   ```

3. **Memory/CPU Limits**
   ```bash
   # Check if pod is being OOMKilled
   kubectl describe pod postgresql-0 -n data-platform
   
   # Look for "Reason: OOMKilled" in events
   # Solution: Increase memory limits
   ```

### 2. Database Connection Issues

#### Airflow Cannot Connect to PostgreSQL

**Symptoms:**
```bash
# Airflow scheduler logs show connection errors
kubectl logs -l component=scheduler -n data-platform
# Error: could not connect to server: Connection refused
```

**Diagnosis & Solutions:**

1. **Check PostgreSQL Service**
   ```bash
   kubectl get svc -n data-platform
   kubectl describe svc postgresql -n data-platform
   
   # Test connection from within cluster
   kubectl run -it --rm debug --image=postgres:13 --restart=Never -- \
     psql -h postgresql -U airflow -d airflow
   ```

2. **Check Database Credentials**
   ```bash
   kubectl get secrets -n data-platform
   kubectl get secret postgresql-secret -o yaml -n data-platform
   
   # Decode base64 values to verify passwords
   echo "encoded_password" | base64 -d
   ```

3. **Check Network Policies**
   ```bash
   kubectl get networkpolicies -n data-platform
   
   # Ensure policies allow communication between Airflow and PostgreSQL
   ```

### 3. Spark Job Execution Issues

#### Spark Jobs Fail to Start

**Symptoms:**
```bash
# Airflow DAG shows Spark tasks failing
# Check Airflow task logs for Spark-related errors
```

**Diagnosis & Solutions:**

1. **Check Spark RBAC Permissions**
   ```bash
   kubectl get rolebinding -n data-platform
   kubectl describe rolebinding spark-driver -n data-platform
   
   # Ensure spark-driver service account has pod creation permissions
   ```

2. **Check Spark Configuration**
   ```bash
   kubectl get configmap spark-config -o yaml -n data-platform
   
   # Verify pod templates and Spark configuration
   ```

3. **Check Image Pull Issues**
   ```bash
   # Look for ImagePullBackOff in Spark driver/executor pods
   kubectl get pods -l spark-role=driver -n data-platform
   
   # Check image pull secrets
   kubectl get secrets -n data-platform | grep registry
   ```

#### Spark Executors Not Starting

**Symptoms:**
```bash
# Spark driver starts but executors remain in pending state
kubectl get pods -l spark-role=executor -n data-platform
```

**Solutions:**

1. **Check Resource Quotas**
   ```bash
   kubectl describe resourcequota -n data-platform
   
   # Ensure enough CPU/memory quota for executor pods
   ```

2. **Check Executor Service Account**
   ```bash
   kubectl get sa spark-executor -n data-platform
   kubectl describe rolebinding spark-executor -n data-platform
   ```

### 4. Image Pull Issues

#### ImagePullBackOff Errors

**Symptoms:**
```bash
kubectl get pods -n data-platform
NAME                     READY   STATUS             RESTARTS   AGE
airflow-webserver-xxx   0/1     ImagePullBackOff   0          2m
```

**Diagnosis & Solutions:**

1. **Check Image Pull Secrets**
   ```bash
   kubectl get secrets -n data-platform
   kubectl describe secret registry-secret -n data-platform
   
   # Verify secret is properly configured
   kubectl get secret registry-secret -o yaml -n data-platform
   ```

2. **Test Registry Access**
   ```bash
   # Test image pull manually
   kubectl run test-pull --image=nexus.enterprise.com/airflow:2.10.0 \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **Check Image Names and Tags**
   ```bash
   # Verify image names in values.yaml match registry
   helm get values my-data-platform -n data-platform
   ```

### 5. Storage Issues

#### PVC Stuck in Pending

**Symptoms:**
```bash
kubectl get pvc -n data-platform
NAME                STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgresql-pvc     Pending                                      premium-ssd     5m
```

**Solutions:**

1. **Check Storage Class**
   ```bash
   kubectl get storageclass
   kubectl describe storageclass premium-ssd
   
   # Ensure storage class exists and is available
   ```

2. **Check PVC Configuration**
   ```bash
   kubectl describe pvc postgresql-pvc -n data-platform
   
   # Look for events describing the issue
   ```

3. **Check Node Storage Capacity**
   ```bash
   kubectl describe nodes | grep -A 10 "Capacity"
   ```

### 6. Performance Issues

#### Slow DAG Execution

**Symptoms:**
- DAGs taking longer than expected to complete
- High resource utilization

**Diagnosis & Solutions:**

1. **Check Resource Utilization**
   ```bash
   # Monitor pod resource usage
   kubectl top pods -n data-platform
   kubectl top nodes
   ```

2. **Analyze Airflow Metrics**
   ```bash
   # Check scheduler performance
   kubectl logs -l component=scheduler -n data-platform | grep "DagFileProcessor"
   
   # Check for database connection pool issues
   kubectl logs -l component=scheduler -n data-platform | grep "pool"
   ```

3. **Optimize Spark Configuration**
   ```bash
   # Review Spark configuration in ConfigMap
   kubectl get configmap spark-config -o yaml -n data-platform
   
   # Consider adjusting:
   # - spark.sql.adaptive.coalescePartitions.parallelismFirst
   # - spark.sql.adaptive.advisoryPartitionSizeInBytes
   # - spark.dynamicAllocation settings
   ```

### 7. Networking Issues

#### Ingress Not Working

**Symptoms:**
- Cannot access Airflow UI from external network
- Ingress shows backend errors

**Solutions:**

1. **Check Ingress Configuration**
   ```bash
   kubectl get ingress -n data-platform
   kubectl describe ingress airflow-ingress -n data-platform
   ```

2. **Check Service Endpoints**
   ```bash
   kubectl get endpoints -n data-platform
   kubectl describe svc airflow-webserver -n data-platform
   ```

3. **Test Internal Connectivity**
   ```bash
   # Port forward to test service directly
   kubectl port-forward svc/airflow-webserver 8080:8080 -n data-platform
   ```

### 8. Security Issues

#### RBAC Permission Denied

**Symptoms:**
```bash
# Pods logs show "forbidden" errors
kubectl logs -l component=scheduler -n data-platform
# Error: pods is forbidden: User "system:serviceaccount:data-platform:airflow" 
# cannot create resource "pods" in API group "" in the namespace "data-platform"
```

**Solutions:**

1. **Check Service Account Bindings**
   ```bash
   kubectl get rolebinding -n data-platform
   kubectl describe rolebinding airflow -n data-platform
   ```

2. **Verify Service Account Usage**
   ```bash
   kubectl get pods -o yaml -n data-platform | grep serviceAccount
   ```

3. **Check Role Permissions**
   ```bash
   kubectl describe role airflow -n data-platform
   ```

## Diagnostic Commands

### Quick Health Check Script

```bash
#!/bin/bash
# health-check.sh - Quick platform health check

NAMESPACE="data-platform"

echo "=== Pod Status ==="
kubectl get pods -n $NAMESPACE

echo -e "\n=== Service Status ==="
kubectl get svc -n $NAMESPACE

echo -e "\n=== PVC Status ==="
kubectl get pvc -n $NAMESPACE

echo -e "\n=== Recent Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10

echo -e "\n=== Resource Usage ==="
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"
```

### Log Collection Script

```bash
#!/bin/bash
# collect-logs.sh - Collect logs for troubleshooting

NAMESPACE="data-platform"
OUTPUT_DIR="platform-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTPUT_DIR

# Collect pod logs
for pod in $(kubectl get pods -n $NAMESPACE -o name); do
    pod_name=$(basename $pod)
    echo "Collecting logs for $pod_name..."
    kubectl logs $pod_name -n $NAMESPACE > "$OUTPUT_DIR/${pod_name}.log" 2>&1
    kubectl logs $pod_name -n $NAMESPACE --previous > "$OUTPUT_DIR/${pod_name}-previous.log" 2>/dev/null
done

# Collect descriptions
kubectl describe pods -n $NAMESPACE > "$OUTPUT_DIR/pods-describe.txt"
kubectl describe svc -n $NAMESPACE > "$OUTPUT_DIR/services-describe.txt"
kubectl get events -n $NAMESPACE > "$OUTPUT_DIR/events.txt"

echo "Logs collected in $OUTPUT_DIR/"
tar -czf "${OUTPUT_DIR}.tar.gz" $OUTPUT_DIR
echo "Archive created: ${OUTPUT_DIR}.tar.gz"
```

## Getting Help

### Debug Mode Deployment

For troubleshooting, deploy with debug mode enabled:

```bash
helm install debug-platform ./helm-charts/umbrella-chart \
  --set global.debug=true \
  --set airflow.webserver.extraEnv[0].name=AIRFLOW__LOGGING__LOGGING_LEVEL \
  --set airflow.webserver.extraEnv[0].value=DEBUG \
  --namespace data-platform-debug \
  --create-namespace
```

### Contact Information

- **Platform Team**: data-platform@enterprise.com
- **Kubernetes Support**: k8s-support@enterprise.com
- **Emergency Escalation**: +1-555-PLATFORM

### Useful Resources

- [Airflow Documentation](https://airflow.apache.org/docs/)
- [Spark on Kubernetes Guide](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [PostgreSQL Troubleshooting](https://www.postgresql.org/docs/current/server-shutdown.html)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)