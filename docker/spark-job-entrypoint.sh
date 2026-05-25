#!/bin/bash
set -e
export HOME=/tmp
export USER="${USER:-root}"
export HADOOP_USER_NAME="${HADOOP_USER_NAME:-root}"
export IVY_HOME=/tmp/.ivy2
mkdir -p "$IVY_HOME"
# Demo Docker: local[*] evita falha de UGI nos workers (uid sem passwd no volume montado).
if [[ "${SPARK_DEMO_LOCAL:-1}" == "1" ]]; then
  SPARK_MASTER="local[*]"
else
  SPARK_MASTER="${SPARK_MASTER_URL:-spark://spark-master:7077}"
fi
SPARK_EXTRA_CONF=(
  --conf "spark.hadoop.security.authentication=simple"
  --conf "spark.hadoop.hadoop.security.authentication=simple"
  --conf "spark.driver.extraJavaOptions=-Duser.home=/tmp -Duser.name=root"
  --conf "spark.executor.extraJavaOptions=-Duser.home=/tmp -Duser.name=root"
)
echo "Aguardando Spark master..."
for i in $(seq 1 60); do
  if curl -sf http://spark-master:8080/ >/dev/null 2>&1; then
    echo "Spark master OK"
    break
  fi
  sleep 2
done
echo "Spark master: $SPARK_MASTER"
echo "Executando pipeline Spark (PySpark)..."
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Duser.home=/tmp -Duser.name=root"
export PYSPARK_PYTHON="${PYSPARK_PYTHON:-python3}"
export PYSPARK_DRIVER_PYTHON="${PYSPARK_DRIVER_PYTHON:-python3}"
exec python3 /workspace/scripts/spark_local_pipeline.py \
  --master "$SPARK_MASTER" \
  --input "${SPARK_INPUT:-data/transactions.json}"