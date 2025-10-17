#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=chaos-canary
SERVICE=chaos-app
CANARY_LABEL='role=canary'
THRESHOLD=0.2 # 20% error threshold to trigger rollback
SAMPLE_REQUESTS=100

echo "Finding canary pod..."
CANARY_POD=$(kubectl -n ${NAMESPACE} get pods -l ${CANARY_LABEL} -o jsonpath='{.items[0].metadata.name}')
echo "Canary pod: ${CANARY_POD}"

echo "Enabling failure mode on canary pod (error_rate=0.5)..."
kubectl -n ${NAMESPACE} exec ${CANARY_POD} -- \
  curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"enabled": true, "error_rate": 0.5, "latency_seconds": 0.1}' \
  http://127.0.0.1:5000/failure || true

echo "Sending ${SAMPLE_REQUESTS} requests to service to measure error rate..."
ERRORS=0
for i in $(seq 1 ${SAMPLE_REQUESTS}); do
  HTTP_CODE=$(kubectl -n ${NAMESPACE} exec ${CANARY_POD} -- \
    curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5000/ || true)
  if [ "${HTTP_CODE}" != "200" ]; then
    ERRORS=$((ERRORS + 1))
  fi
done

ERROR_RATE=$(awk "BEGIN {printf \"%.2f\", ${ERRORS}/${SAMPLE_REQUESTS}}")
echo "Observed error rate: ${ERROR_RATE}"

awk "BEGIN{ if (${ERROR_RATE} > ${THRESHOLD}) exit 0; else exit 1 }"
RET=$?
if [ $RET -eq 0 ]; then
  echo "Error rate ${ERROR_RATE} > ${THRESHOLD}. Rolling back (deleting canary)."
  kubectl -n ${NAMESPACE} delete deployment chaos-app-canary || true
  exit 1
else
  echo "Error rate acceptable (${ERROR_RATE}). Promoting canary is left as a manual step for safety."
fi
