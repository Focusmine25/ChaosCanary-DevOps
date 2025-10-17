#!/usr/bin/env bash
set -euo pipefail


NAMESPACE=chaos-canary
PROM_SVC=prometheus
PROM_LOCAL_PORT=9090
THRESHOLD=0.2
CANARY_POD_LABEL='role=canary'

PF_PID=0

cleanup() {
  if [ -n "${PF_PID:-}" ] && kill -0 ${PF_PID} >/dev/null 2>&1; then
    kill ${PF_PID} >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "Port-forwarding Prometheus service to localhost:${PROM_LOCAL_PORT}"
kubectl -n ${NAMESPACE} port-forward svc/${PROM_SVC} ${PROM_LOCAL_PORT}:9090 >/dev/null 2>&1 &
PF_PID=$!

echo "Waiting for Prometheus to be ready on localhost:${PROM_LOCAL_PORT}..."
READY=0
for i in $(seq 1 30); do
  if curl -sSf "http://localhost:${PROM_LOCAL_PORT}/-/ready" >/dev/null 2>&1; then
    READY=1
    echo "Prometheus is ready"
    break
  fi
  sleep 1
done
if [ ${READY} -ne 1 ]; then
  echo "Prometheus did not report ready; continuing but the query may not have data yet"
fi

echo "Enabling failure mode on canary pod"
CANARY_POD=$(kubectl -n ${NAMESPACE} get pods -l ${CANARY_POD_LABEL} -o jsonpath='{.items[0].metadata.name}')
kubectl -n ${NAMESPACE} exec ${CANARY_POD} -- \
  curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"enabled": true, "error_rate": 0.5, "latency_seconds": 0.1}' \
  http://127.0.0.1:5000/failure || true


echo "Waiting for Prometheus to scrape metrics (allowing additional time)"
sleep 20

# use a slightly longer PromQL window to reduce flakiness on short-lived clusters
PROM_QUERY='sum(rate(app_errors_total[60s])) / sum(rate(app_requests_total[60s]))'
echo "Running PromQL: ${PROM_QUERY}"

ENC_QUERY=$(python3 - <<PY
import urllib.parse
q = """%s""" % ("${PROM_QUERY}",)
print(urllib.parse.quote(q))
PY
)

RESULT="0"
for i in $(seq 1 8); do
  echo "Prometheus query attempt #${i}"
  RAW=$(curl -s "http://localhost:${PROM_LOCAL_PORT}/api/v1/query?query=${ENC_QUERY}" || true)
  if [ -n "$RAW" ]; then
    # save raw response for debugging if needed
    echo "$RAW" > /tmp/prom_response.json || true
    VAL=$(echo "$RAW" | jq -r '.data.result[0].value[1] // "0"') || VAL="0"
    echo "Raw Prometheus response (truncated): $(echo "$RAW" | head -c 400)"
    if [ "$VAL" != "0" ]; then
      RESULT="$VAL"
      break
    fi
  else
    echo "Prometheus query returned empty; retrying... ($i)"
  fi
  sleep 3
done

echo "Prometheus reported error rate: ${RESULT}"

# cleanup will kill port-forward

awk "BEGIN{ if (${RESULT} > ${THRESHOLD}) exit 0; else exit 1 }"
RET=$?
if [ $RET -eq 0 ]; then
  echo "SLI breached (${RESULT} > ${THRESHOLD}). Rolling back canary."
  kubectl -n ${NAMESPACE} delete deployment chaos-app-canary || true
  exit 1
else
  echo "SLI OK (${RESULT} <= ${THRESHOLD})." && exit 0
fi
