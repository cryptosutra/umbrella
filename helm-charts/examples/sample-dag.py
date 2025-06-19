# Example DAG showing how to trigger Spark jobs from Airflow
# Place this file in your DAGs directory

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator

default_args = {
    'owner': 'data-platform',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'spark_example_workflow',
    default_args=default_args,
    description='Example workflow that runs Spark jobs',
    schedule_interval=timedelta(hours=1),
    catchup=False,
    tags=['example', 'spark', 'etl'],
)

# Check database connectivity
check_db = PostgresOperator(
    task_id='check_database',
    postgres_conn_id='postgres_default',
    sql='SELECT 1;',
    dag=dag,
)

# Example Spark job configuration
spark_job_config = {
    'apiVersion': 'sparkoperator.k8s.io/v1beta2',
    'kind': 'SparkApplication',
    'metadata': {
        'name': 'example-spark-job-{{ ds_nodash }}',
        'namespace': '{{ var.value.kubernetes_namespace }}',
    },
    'spec': {
        'type': 'Python',
        'pythonVersion': '3',
        'mode': 'cluster',
        'image': 'nexus.enterprise.com/spark:3.5.0',
        'imagePullPolicy': 'IfNotPresent',
        'mainApplicationFile': 'local:///opt/spark/examples/src/main/python/pi.py',
        'arguments': ['10'],
        'sparkVersion': '3.5.0',
        'restartPolicy': {
            'type': 'Never'
        },
        'driver': {
            'cores': 1,
            'coreLimit': '1200m',
            'memory': '1g',
            'serviceAccount': 'spark-driver',
            'labels': {
                'version': '3.5.0'
            }
        },
        'executor': {
            'cores': 1,
            'instances': 2,
            'memory': '1g',
            'serviceAccount': 'spark-executor',
            'labels': {
                'version': '3.5.0'
            }
        }
    }
}

# Run Spark job using KubernetesOperator
run_spark_job = SparkKubernetesOperator(
    task_id='run_spark_calculation',
    namespace='{{ var.value.kubernetes_namespace }}',
    application_file=spark_job_config,
    do_xcom_push=True,
    dag=dag,
)

# Set task dependencies
check_db >> run_spark_job