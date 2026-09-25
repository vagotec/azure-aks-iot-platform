#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAMESPACE="azure-aks-iot"
GATEWAY_NAME="azure-aks-iot-platform"

COMMAND='test'
COMMAND_VALUE='phase-4b-frontend'

EXPECTED_COMMAND="$(
  printf \
    '{"command":"%s","value":"%s"}' \
    "${COMMAND}" \
    "${COMMAND_VALUE}"
)"

TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

echo "============================================================"
echo " TEST - React Frontend E2E"
echo "============================================================"

GATEWAY_ADDRESS="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.addresses[0].value}'
)"

BASE_URL="http://${GATEWAY_ADDRESS}"

echo "Gateway URL: ${BASE_URL}"

# ------------------------------------------------------------
# TEST 1 - React application through Envoy
# ------------------------------------------------------------

echo
echo "=== TEST 1/4 - React application through Envoy ==="

FRONTEND_HTML="$(
  curl \
    --silent \
    --show-error \
    --fail \
    --max-time 10 \
    "${BASE_URL}/"
)"

if ! grep -Fq \
  '<div id="root"></div>' \
  <<<"${FRONTEND_HTML}"; then

  echo "ERROR: React root element not found."
  exit 1
fi

echo "PASSED: Envoy -> React Frontend"

# ------------------------------------------------------------
# TEST 2 - REST Health through Envoy
# ------------------------------------------------------------

echo
echo "=== TEST 2/4 - REST health through Envoy ==="

HEALTH_RESPONSE="$(
  curl \
    --silent \
    --show-error \
    --fail \
    --max-time 10 \
    "${BASE_URL}/api/health"
)"

echo "Response: ${HEALTH_RESPONSE}"

python3 - "${HEALTH_RESPONSE}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])

if data.get("status") != "ok":
    raise SystemExit(
        "ERROR: Backend health status is not ok."
    )

if data.get("service") != "vagotec_backend_service":
    raise SystemExit(
        "ERROR: Unexpected Backend service."
    )

print("Validated: status=ok")
print("Validated: service=vagotec_backend_service")
PY

echo "PASSED: Envoy -> C++ Backend health API"

# ------------------------------------------------------------
# TEST 3 - Telemetry through Envoy
# ------------------------------------------------------------

echo
echo "=== TEST 3/4 - Telemetry through Envoy ==="

TELEMETRY_RESPONSE="$(
  curl \
    --silent \
    --show-error \
    --fail \
    --max-time 10 \
    "${BASE_URL}/api/telemetry/latest"
)"

echo "Response: ${TELEMETRY_RESPONSE}"

python3 - "${TELEMETRY_RESPONSE}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])

required = (
    "device_id",
    "temperature_c",
    "humidity_percent",
)

for field in required:
    if field not in data:
        raise SystemExit(
            f"ERROR: Missing telemetry field: {field}"
        )

if not isinstance(data["device_id"], str):
    raise SystemExit(
        "ERROR: device_id is not a string."
    )

if not isinstance(
    data["temperature_c"],
    (int, float),
):
    raise SystemExit(
        "ERROR: temperature_c is not numeric."
    )

if not isinstance(
    data["humidity_percent"],
    (int, float),
):
    raise SystemExit(
        "ERROR: humidity_percent is not numeric."
    )

print(
    f'device_id        : {data["device_id"]}'
)
print(
    f'temperature_c    : {data["temperature_c"]}'
)
print(
    f'humidity_percent : {data["humidity_percent"]}'
)
PY

echo "PASSED: ROS 2 -> C++ Backend -> REST -> Envoy"

# ------------------------------------------------------------
# TEST 4 - Full command round-trip through Envoy
# ------------------------------------------------------------

echo
echo "=== TEST 4/4 - Command full round-trip through Envoy ==="

HTTP_BODY="${TMP_DIR}/command-response.json"

HTTP_STATUS="$(
  curl \
    --silent \
    --show-error \
    --output "${HTTP_BODY}" \
    --write-out '%{http_code}' \
    --max-time 10 \
    --request POST \
    --header 'Content-Type: application/json' \
    --data "${EXPECTED_COMMAND}" \
    "${BASE_URL}/api/commands"
)"

COMMAND_RESPONSE="$(cat "${HTTP_BODY}")"

echo "HTTP status: ${HTTP_STATUS}"
echo "Response:    ${COMMAND_RESPONSE}"

if [[ "${HTTP_STATUS}" != "200" ]]; then
  echo "ERROR: Expected HTTP 200."
  exit 1
fi

python3 - \
  "${COMMAND_RESPONSE}" \
  "${COMMAND}" \
  "${COMMAND_VALUE}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
command = sys.argv[2]
value = sys.argv[3]

if data.get("success") is not True:
    raise SystemExit(
        "ERROR: Device did not report success."
    )

if data.get("status") != "executed":
    raise SystemExit(
        "ERROR: Device status is not executed."
    )

expected_message = (
    f"Simulator executed command '{command}' "
    f"with value '{value}'"
)

if data.get("message") != expected_message:
    raise SystemExit(
        "ERROR: Unexpected device response.\n"
        f"Expected: {expected_message}\n"
        f"Actual:   {data.get('message')}"
    )

print("Validated: success=true")
print("Validated: status=executed")
print(
    f"Validated: message={data['message']}"
)
PY

echo
echo "PASSED:"
echo "Envoy"
echo "  -> C++ Backend"
echo "  -> ROS 2 DeviceCommand Service"
echo "  -> Simulator"
echo "  -> DeviceCommand Response"
echo "  -> C++ Backend"
echo "  -> Envoy"

echo
echo "============================================================"
echo " FRONTEND FUNCTIONAL TEST PASSED"
echo "============================================================"
echo " React /                              : PASSED"
echo " GET /api/health                      : PASSED"
echo " GET /api/telemetry/latest            : PASSED"
echo " POST /api/commands full round-trip    : PASSED"
echo "============================================================"
