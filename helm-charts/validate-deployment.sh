#!/bin/bash
# validate-deployment.sh - Validation script for the Enterprise Data Platform

set -e

# Configuration
NAMESPACE=${1:-"data-platform"}
RELEASE_NAME=${2:-"enterprise-data-platform"}
TIMEOUT=300  # 5 minutes timeout for health checks

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Enterprise Data Platform Deployment Validation ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Function to check if command is available
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local label_selector=$1
    local expected_count=$2
    local component=$3
    
    echo -n "Waiting for $component pods to be ready..."
    
    local end_time=$((SECONDS + TIMEOUT))
    while [ $SECONDS -lt $end_time ]; do
        local ready_count=$(kubectl get pods -n $NAMESPACE -l "$label_selector" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [ "$ready_count" -eq "$expected_count" ]; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
    
    echo -e " ${RED}✗${NC}"
    echo -e "${RED}Timeout waiting for $component pods${NC}"
    kubectl get pods -n $NAMESPACE -l "$label_selector"
    return 1
}

# Function to check service connectivity
check_service() {
    local service_name=$1
    local port=$2
    local component=$3
    
    echo -n "Checking $component service connectivity..."
    
    # Test service resolution
    if kubectl get svc $service_name -n $NAMESPACE &>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        return 0
    else
        echo -e " ${RED}✗${NC}"
        echo -e "${RED}Service $service_name not found${NC}"
        return 1
    fi
}

# Function to test database connectivity
test_database() {
    echo -n "Testing PostgreSQL database connectivity..."
    
    # Create a test pod to check database connection
    kubectl run db-test --rm -i --restart=Never --image=postgres:13 -n $NAMESPACE -- \
        bash -c "PGPASSWORD=airflow123 psql -h $RELEASE_NAME-postgresql -U airflow -d airflow -c 'SELECT 1;'" &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e " ${GREEN}✓${NC}"
        return 0
    else
        echo -e " ${RED}✗${NC}"
        echo -e "${RED}Database connection failed${NC}"
        return 1
    fi
}

# Function to test Airflow API
test_airflow_api() {
    echo -n "Testing Airflow API..."
    
    # Port forward to test API
    kubectl port-forward svc/$RELEASE_NAME-airflow-webserver 8080:8080 -n $NAMESPACE &>/dev/null &
    local pf_pid=$!
    sleep 5
    
    # Test API endpoint
    local api_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
    
    # Clean up port forward
    kill $pf_pid 2>/dev/null
    
    if [ "$api_response" = "200" ]; then
        echo -e " ${GREEN}✓${NC}"
        return 0
    else
        echo -e " ${RED}✗ (HTTP $api_response)${NC}"
        return 1
    fi
}

# Function to validate Spark configuration
validate_spark_config() {
    echo -n "Validating Spark configuration..."
    
    # Check if Spark ConfigMap exists and has required configs
    local spark_config=$(kubectl get configmap $RELEASE_NAME-spark-config -n $NAMESPACE -o jsonpath='{.data.spark-defaults\.conf}' 2>/dev/null)
    
    if [[ $spark_config == *"spark.kubernetes.authenticate.driver.serviceAccountName"* ]]; then
        echo -e " ${GREEN}✓${NC}"
        return 0
    else
        echo -e " ${RED}✗${NC}"
        echo -e "${RED}Spark configuration incomplete${NC}"
        return 1
    fi
}

# Function to check RBAC permissions
check_rbac() {
    echo -n "Checking RBAC permissions..."
    
    # Check if service accounts exist
    kubectl get sa airflow spark-driver spark-executor -n $NAMESPACE &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e " ${GREEN}✓${NC}"
        return 0
    else
        echo -e " ${RED}✗${NC}"
        echo -e "${RED}Service accounts not found${NC}"
        return 1
    fi
}

# Function to check storage
check_storage() {
    echo -n "Checking persistent storage..."
    
    local pvc_count=$(kubectl get pvc -n $NAMESPACE --no-headers | wc -l)
    local bound_count=$(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[?(@.status.phase=="Bound")].metadata.name}' | wc -w)
    
    if [ "$bound_count" -gt 0 ] && [ "$bound_count" -eq "$pvc_count" ]; then
        echo -e " ${GREEN}✓${NC}"
        echo "  PVCs bound: $bound_count/$pvc_count"
        return 0
    else
        echo -e " ${RED}✗${NC}"
        echo -e "${RED}PVCs not bound: $bound_count/$pvc_count${NC}"
        kubectl get pvc -n $NAMESPACE
        return 1
    fi
}

# Function to run a test Spark job
test_spark_job() {
    echo -n "Testing Spark job execution (this may take a few minutes)..."
    
    # Create a simple test Spark job
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: spark-test-job
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  serviceAccountName: spark-driver
  containers:
  - name: spark-submit
    image: nexus.enterprise.com/spark:3.5.0
    command: ["/opt/spark/bin/spark-submit"]
    args:
      - "--master=k8s://https://kubernetes.default.svc.cluster.local:443"
      - "--deploy-mode=cluster"
      - "--name=test-spark-job"
      - "--conf=spark.kubernetes.authenticate.driver.serviceAccountName=spark-driver"
      - "--conf=spark.kubernetes.authenticate.executor.serviceAccountName=spark-executor"
      - "--conf=spark.kubernetes.container.image=nexus.enterprise.com/spark:3.5.0"
      - "--conf=spark.kubernetes.namespace=$NAMESPACE"
      - "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar"
      - "10"
EOF
    
    # Wait for job to complete
    kubectl wait --for=condition=Ready pod/spark-test-job -n $NAMESPACE --timeout=300s &>/dev/null
    local job_status=$?
    
    # Clean up test job
    kubectl delete pod spark-test-job -n $NAMESPACE &>/dev/null
    
    if [ $job_status -eq 0 ]; then
        echo -e " ${GREEN}✓${NC}"
        return 0
    else
        echo -e " ${RED}✗${NC}"
        echo -e "${RED}Spark job test failed${NC}"
        return 1
    fi
}

# Main validation function
main() {
    local failures=0
    
    # Check required commands
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    check_command kubectl
    check_command helm
    check_command curl
    echo ""
    
    # Check if release exists
    echo -e "${YELLOW}Checking deployment status...${NC}"
    if ! helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        echo -e "${RED}Release $RELEASE_NAME not found in namespace $NAMESPACE${NC}"
        exit 1
    fi
    echo -e "${GREEN}Release found${NC}"
    echo ""
    
    # Validate core components
    echo -e "${YELLOW}Validating core components...${NC}"
    
    # PostgreSQL
    wait_for_pods "app.kubernetes.io/name=postgresql" 1 "PostgreSQL" || ((failures++))
    check_service "$RELEASE_NAME-postgresql" 5432 "PostgreSQL" || ((failures++))
    test_database || ((failures++))
    
    # Airflow
    wait_for_pods "app.kubernetes.io/name=airflow,component=webserver" 1 "Airflow Webserver" || ((failures++))
    wait_for_pods "app.kubernetes.io/name=airflow,component=scheduler" 1 "Airflow Scheduler" || ((failures++))
    check_service "$RELEASE_NAME-airflow-webserver" 8080 "Airflow Webserver" || ((failures++))
    test_airflow_api || ((failures++))
    
    echo ""
    
    # Validate configuration
    echo -e "${YELLOW}Validating configuration...${NC}"
    validate_spark_config || ((failures++))
    check_rbac || ((failures++))
    check_storage || ((failures++))
    
    echo ""
    
    # Optional: Test Spark job (uncomment if needed)
    # echo -e "${YELLOW}Testing Spark integration...${NC}"
    # test_spark_job || ((failures++))
    # echo ""
    
    # Summary
    echo -e "${YELLOW}=== Validation Summary ===${NC}"
    
    if [ $failures -eq 0 ]; then
        echo -e "${GREEN}✓ All validations passed!${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Access Airflow UI: kubectl port-forward svc/$RELEASE_NAME-airflow-webserver 8080:8080 -n $NAMESPACE"
        echo "2. Login with: admin/admin"
        echo "3. Configure Spark connection in Airflow"
        echo "4. Deploy your DAGs to start processing workflows"
        echo ""
        exit 0
    else
        echo -e "${RED}✗ $failures validation(s) failed${NC}"
        echo ""
        echo -e "${YELLOW}Troubleshooting tips:${NC}"
        echo "1. Check pod logs: kubectl logs -l app.kubernetes.io/name=<component> -n $NAMESPACE"
        echo "2. Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
        echo "3. Verify resource quotas: kubectl describe resourcequota -n $NAMESPACE"
        echo "4. Check storage classes: kubectl get storageclass"
        echo ""
        exit 1
    fi
}

# Run main function
main