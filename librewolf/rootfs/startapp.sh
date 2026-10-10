#!/bin/sh
set -eu

###############################################################################
# Configuration
###############################################################################

USE_TOR="${USE_TOR:-0}"

MITMPROXY_DIR="/tmp/mitmproxy"
MITMPROXY_CA="${MITMPROXY_DIR}/mitmproxy-ca-cert.pem"
MITMPROXY_HOST="127.0.0.1"
MITMPROXY_PORT=8080

BROWSER_PROFILE="/tmp/librewolf-profile"

MITMWEB_HOST="0.0.0.0"
MITMWEB_PORT=8081

TOR_DATA_DIR="/tmp/tor"
TOR_LOG="/tmp/tor.log"
TOR_SOCKS_HOST="127.0.0.1"
TOR_SOCKS_PORT=9050

GOST_HOST="127.0.0.1"
GOST_PORT=8082

log() { echo "[${BROWSER_TO_USE}-mitmproxy] $*"; }

###############################################################################
# Helpers
###############################################################################
wait_for_file() {
    file="$1"
    pid="$2"
    log_file="$3"
    attempts="${4:-300}"

    i=0
    while [ ! -s "$file" ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            log "ERROR: Process exited before creating $file."
            cat "$log_file" 2>/dev/null || true
            return 1
        fi

        i=$((i + 1))
        if [ "$i" -ge "$attempts" ]; then
            log "ERROR: Timed out waiting for $file."
            cat "$log_file" 2>/dev/null || true
            return 1
        fi
        sleep 0.1
    done
}

wait_for_port() {
    host="$1"
    port="$2"
    pid="$3"
    log_file="$4"
    attempts="${5:-100}"

    i=0
    while ! nc -z "$host" "$port" >/dev/null 2>&1; do
        if ! kill -0 "$pid" 2>/dev/null; then
            log "ERROR: Process exited before $host:$port became available."
            cat "$log_file" 2>/dev/null || true
            return 1
        fi

        i=$((i + 1))
        if [ "$i" -ge "$attempts" ]; then
            log "ERROR: Timed out waiting for $host:$port."
            cat "$log_file" 2>/dev/null || true
            return 1
        fi
        sleep 0.1
    done
}

###############################################################################
# Validate configuration
###############################################################################

case "$USE_TOR" in
    0|1) ;;
    *) log "ERROR: USE_TOR must be 0 or 1."; exit 1 ;;
esac

###############################################################################
# Generate mitmproxy CA
###############################################################################

log "Generating fresh mitmproxy CA..."

rm -rf "$MITMPROXY_DIR"
mkdir -p "$MITMPROXY_DIR"

mitmdump --set confdir="$MITMPROXY_DIR" \
    --set listen_host=127.0.0.1 --set listen_port=8080 \
    >/tmp/mitmproxy-init.log 2>&1 &

MITMDUMP_PID=$!
if ! wait_for_file "$MITMPROXY_CA" "$MITMDUMP_PID" /tmp/mitmproxy-init.log; then
    kill "$MITMDUMP_PID" 2>/dev/null || true
    wait "$MITMDUMP_PID" 2>/dev/null || true
    exit 1
fi

kill "$MITMDUMP_PID" 2>/dev/null || true
wait "$MITMDUMP_PID" 2>/dev/null || true

###############################################################################
# Prepare LibreWolf profile and trust the mitmproxy CA
###############################################################################

log "Preparing LibreWolf profile..."

rm -rf "$BROWSER_PROFILE"
mkdir -p "$BROWSER_PROFILE"

certutil -N -d "sql:$BROWSER_PROFILE" --empty-password
certutil -A -d "sql:$BROWSER_PROFILE" -n "mitmproxy" -t "C,," -a -i "$MITMPROXY_CA"

if ! certutil -L -d "sql:$BROWSER_PROFILE" | grep -q "mitmproxy"; then
    log "ERROR: mitmproxy CA import verification failed."
    certutil -L -d "sql:$BROWSER_PROFILE" || true
    exit 1
fi

###############################################################################
# Start optional Tor and GOST
###############################################################################

if [ "$USE_TOR" = "1" ]; then
    log "Starting TOR..."

    rm -rf "$TOR_DATA_DIR"
    mkdir -p "$TOR_DATA_DIR"
    chmod 700 "$TOR_DATA_DIR"

    tor --DataDirectory "$TOR_DATA_DIR" \
        --SocksPort "$TOR_SOCKS_HOST:$TOR_SOCKS_PORT" \
        --Log "notice file $TOR_LOG" \
        >/tmp/tor-console.log 2>&1 &
    
    TOR_PID=$!
    i=0
    while ! grep -qi "Bootstrapped 100%" "$TOR_LOG" 2>/dev/null; do
        if ! kill -0 "$TOR_PID" 2>/dev/null; then
            log "ERROR: TOR exited unexpectedly."
            cat /tmp/tor-console.log "$TOR_LOG" 2>/dev/null || true
            exit 1
        fi

        i=$((i + 1))
        if [ "$i" -ge 600 ]; then
            log "ERROR: TOR bootstrap timed out."
            cat /tmp/tor-console.log "$TOR_LOG" 2>/dev/null || true
            kill "$TOR_PID" 2>/dev/null || true
            exit 1
        fi
        sleep 0.1
    done

    log "TOR bootstrapped; starting GOST..."

    gost -L "http://$GOST_HOST:$GOST_PORT" \
         -F "socks5://$TOR_SOCKS_HOST:$TOR_SOCKS_PORT" \
        >/tmp/gost.log 2>&1 &
    
    GOST_PID=$!
    wait_for_port "$GOST_HOST" "$GOST_PORT" "$GOST_PID" /tmp/gost.log
fi

###############################################################################
# Start mitmweb
###############################################################################
log "Starting mitmweb..."

if [ "$USE_TOR" = "1" ]; then
    mitmweb --set confdir="$MITMPROXY_DIR" \
        --mode "upstream:http://$GOST_HOST:$GOST_PORT" \
        --set listen_host="$MITMPROXY_HOST" --set listen_port="$MITMPROXY_PORT" \
        --set web_host="$MITMWEB_HOST" --set web_port="$MITMWEB_PORT" \
        >/tmp/mitmweb.log 2>&1 &
else
    mitmweb --set confdir="$MITMPROXY_DIR" \
        --set listen_host="$MITMPROXY_HOST" --set listen_port="$MITMPROXY_PORT" \
        --set web_host="$MITMWEB_HOST" --set web_port="$MITMWEB_PORT" \
        >/tmp/mitmweb.log 2>&1 &
fi

MITMWEB_PID=$!
wait_for_port "$MITMPROXY_HOST" "$MITMPROXY_PORT" "$MITMWEB_PID" /tmp/mitmweb.log

log "mitmweb: $MITMPROXY_HOST:$MITMPROXY_PORT (proxy), $MITMWEB_HOST:$MITMWEB_PORT (UI)"
[ "$USE_TOR" = "1" ] && log "Upstream: GOST -> TOR" || log "Upstream: direct"

###############################################################################
# Start LibreWolf
###############################################################################
log "Starting LibreWolf..."
exec librewolf --profile "$BROWSER_PROFILE" --no-remote ${BROWSER_CUSTOM_ARGS:-}
