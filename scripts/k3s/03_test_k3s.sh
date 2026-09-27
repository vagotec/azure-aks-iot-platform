#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${PROJECT_ROOT}/.state/k3s"

echo "============================================================"
echo " TEST K3S"
echo "============================================================"

if [[ ! -f "${STATE_DIR}/kubeconfig" ]]; then
    echo "ERROR: Project kubeconfig not found."
    exit 1
fi

export KUBECONFIG="${STATE_DIR}/kubeconfig"

TEST_NAMESPACE="k3s-lifecycle-test"
TEST_POD="api-connectivity-test"

cleanup() {
    kubectl delete namespace "${TEST_NAMESPACE}" \
        --ignore-not-found=true \
        --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "=== DNS and HTTPS connectivity from Pod to Kubernetes API ==="

kubectl create namespace "${TEST_NAMESPACE}" \
    --dry-run=client \
    -o yaml |
kubectl apply -f -

kubectl delete pod "${TEST_POD}" \
    -n "${TEST_NAMESPACE}" \
    --ignore-not-found=true \
    --wait=true

kubectl run "${TEST_POD}" \
    -n "${TEST_NAMESPACE}" \
    --image=curlimages/curl:8.17.0 \
    --restart=Never \
    --command -- \
    sh -c '
        set -eu

        CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        TOKEN_FILE=/var/run/secrets/kubernetes.io/serviceaccount/token

        test -s "${CA}"
        test -s "${TOKEN_FILE}"

        HTTP_CODE="$(
            curl \
                --silent \
                --show-error \
                --output /tmp/api-response \
                --write-out "%{http_code}" \
                --cacert "${CA}" \
                --connect-timeout 10 \
                --max-time 20 \
                https://kubernetes.default.svc/version
        )"

        echo "HTTP status: ${HTTP_CODE}"
        cat /tmp/api-response
        echo

        test "${HTTP_CODE}" = "403" || test "${HTTP_CODE}" = "200"
    '

kubectl wait \
    --for=jsonpath='{.status.phase}'=Succeeded \
    pod/"${TEST_POD}" \
    -n "${TEST_NAMESPACE}" \
    --timeout=120s

kubectl logs "${TEST_POD}" -n "${TEST_NAMESPACE}"

echo
echo "============================================================"
echo " K3S FUNCTIONAL TEST PASSED"
echo " Pod -> DNS -> Service IP :443 -> Kubernetes API -> TLS"
echo "============================================================"
