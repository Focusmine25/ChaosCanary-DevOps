#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=chaos-canary
PROM_SVC=prometheus
PROM_LOCAL_PORT=9090
THRESHOLD=0.2
CANARY_POD_LABEL='role=canary'

echo "Port-forwarding Prometheus service to localhost:${PROM_LOCAL_PORT}"
kubectl -n ${NAMESPACE} port-forward svc/${PROM_SVC} ${PROM_LOCAL_PORT}:9090 >/dev/null 2>&1 &
PF_PID=$!
sleep 2

echo "Enabling failure mode on canary pod"
CANARY_POD=$(kubectl -n ${NAMESPACE} get pods -l ${CANARY_POD_LABEL} -o jsonpath='{.items[0].metadata.name}')
kubectl -n ${NAMESPACE} exec ${CANARY_POD} -- \
  curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"enabled": true, "error_rate": 0.5, "latency_seconds": 0.1}' \
  http://127.0.0.1:5000/failure || true

echo "Waiting 5s for Prometheus to scrape metrics"
sleep 5

PROM_QUERY='sum(rate(app_errors_total[30s])) / sum(rate(app_requests_total[30s]))'
echo "Running PromQL: ${PROM_QUERY}"
ENC_QUERY=$(python3 - <<'PY'
import urllib.parse
q='''%s''' % "${PROM_QUERY}"
print(urllib.parse.quote(q))
PY
)
RESULT=$(curl -s "http://localhost:${PROM_LOCAL_PORT}/api/v1/query?query=${ENC_QUERY}" | jq -r '.data.result[0].value[1] // "0"')
echo "Prometheus reported error rate: ${RESULT}"

kill ${PF_PID} || true

awk "BEGIN{ if (${RESULT} > ${THRESHOLD}) exit 0; else exit 1 }"
RET=$?
if [ $RET -eq 0 ]; then
  echo "SLI breached (${RESULT} > ${THRESHOLD}). Rolling back canary."
  kubectl -n ${NAMESPACE} delete deployment chaos-app-canary || true
  exit 1
else
  echo "SLI OK (${RESULT} <= ${THRESHOLD})." && exit 0
fi
