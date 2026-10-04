#!/bin/sh

set -eu

MITMPROXY_DIR="/tmp/mitmproxy"
MITMPROXY_CA="${MITMPROXY_DIR}/mitmproxy-ca-cert.pem"

LIBREWOLF_PROFILE="/tmp/librewolf-profile"

log() {
    echo "[librewolf-mitmproxy] $*"
}

###############################################################################
# Generate fresh mitmproxy CA
###############################################################################

log "Creating fresh mitmproxy configuration..."

rm -rf "${MITMPROXY_DIR}"
mkdir -p "${MITMPROXY_DIR}"

log "Generating fresh mitmproxy CA..."

mitmdump \
    --set confdir="${MITMPROXY_DIR}" \
    --set listen_host=127.0.0.1 \
    --set listen_port=8080 \
    >/tmp/mitmproxy-init.log 2>&1 &

MITMDUMP_PID=$!

i=0

while [ ! -f "${MITMPROXY_CA}" ]; do
    i=$((i + 1))

    if [ "${i}" -ge 100 ]; then
        echo "ERROR: mitmproxy failed to generate its CA."

        cat /tmp/mitmproxy-init.log || true

        kill "${MITMDUMP_PID}" 2>/dev/null || true
        wait "${MITMDUMP_PID}" 2>/dev/null || true

        exit 1
    fi

    sleep 0.1
done

kill "${MITMDUMP_PID}" 2>/dev/null || true
wait "${MITMDUMP_PID}" 2>/dev/null || true

log "Fresh mitmproxy CA generated:"
log "  ${MITMPROXY_CA}"


###############################################################################
# Create LibreWolf profile
###############################################################################

log "Creating LibreWolf profile..."

rm -rf "${LIBREWOLF_PROFILE}"
mkdir -p "${LIBREWOLF_PROFILE}"


###############################################################################
# Create NSS certificate database
###############################################################################

log "Creating LibreWolf NSS certificate database..."

certutil \
    -N \
    -d "sql:${LIBREWOLF_PROFILE}" \
    --empty-password


###############################################################################
# Import mitmproxy CA
###############################################################################

log "Importing mitmproxy CA into LibreWolf..."

certutil \
    -A \
    -d "sql:${LIBREWOLF_PROFILE}" \
    -n "mitmproxy" \
    -t "C,," \
    -a \
    -i "${MITMPROXY_CA}"

log "mitmproxy CA imported successfully."


###############################################################################
# Verify CA installation
###############################################################################

log "Verifying mitmproxy CA..."

if ! certutil \
    -L \
    -d "sql:${LIBREWOLF_PROFILE}" |
    grep -q "mitmproxy"
then
    echo "ERROR: mitmproxy CA was not found in LibreWolf NSS database."

    certutil \
        -L \
        -d "sql:${LIBREWOLF_PROFILE}" || true

    exit 1
fi

log "LibreWolf NSS database is ready."


###############################################################################
# Start mitmweb
###############################################################################

log "Starting mitmweb..."

mitmweb \
    --set confdir="${MITMPROXY_DIR}" \
    --set listen_host=127.0.0.1 \
    --set listen_port=8080 \
    --set web_host=0.0.0.0 \
    --set web_port=8081 \
    >/tmp/mitmweb.log 2>&1 &

MITMWEB_PID=$!

###############################################################################
# Wait for mitmproxy
###############################################################################

i=0

while ! nc -z 127.0.0.1 8080 >/dev/null 2>&1; do
    i=$((i + 1))

    if [ "${i}" -ge 100 ]; then
        echo "ERROR: mitmweb failed to start."

        cat /tmp/mitmweb.log || true

        kill "${MITMWEB_PID}" 2>/dev/null || true
        wait "${MITMWEB_PID}" 2>/dev/null || true

        exit 1
    fi

    sleep 0.1
done

log "mitmproxy is listening on 127.0.0.1:8080."
log "mitmweb is listening on 0.0.0.0:8081."


###############################################################################
# Start LibreWolf
###############################################################################

log "Starting LibreWolf..."

exec librewolf \
    --profile "${LIBREWOLF_PROFILE}" \
    --no-remote \
    ${LIBREWOLF_CUSTOM_ARGS:-}
