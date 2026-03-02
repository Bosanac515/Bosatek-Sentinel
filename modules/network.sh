#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V2 — modules/network.sh
# Network helpers: VPN wait, interface checks
# ============================================================

# wait_for_vpn <LOG_FILE> [TIMEOUT_SECONDS]
# Blocks until OpenVPN prints "Initialization Sequence Completed"
# or until the optional timeout is reached.
wait_for_vpn() {
    local LOG_FILE="${1:-$HOME/vpn.log}"
    local TIMEOUT="${2:-120}"
    local ELAPSED=0
    local POLL_INTERVAL=2

    echo "[*] Waiting for VPN tunnel..."
    echo "[*] Watching: $LOG_FILE"
    echo "[*] Timeout : ${TIMEOUT}s"
    echo ""

    # Wait for the log file to appear first
    while [[ ! -f "$LOG_FILE" ]]; do
        sleep "$POLL_INTERVAL"
        ELAPSED=$((ELAPSED + POLL_INTERVAL))
        if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
            echo "[!] Timeout waiting for VPN log file: $LOG_FILE"
            return 1
        fi
    done

    # Tail the log and watch for the success marker
    while true; do
        if grep -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
            echo "[+] VPN connected — Initialization Sequence Completed."
            _print_vpn_interface
            return 0
        fi

        # Check for common failure conditions
        if grep -qiE "AUTH_FAILED|TLS Error|Connection refused|SIGTERM" "$LOG_FILE" 2>/dev/null; then
            echo "[!] VPN connection failed. Check $LOG_FILE for details."
            return 2
        fi

        sleep "$POLL_INTERVAL"
        ELAPSED=$((ELAPSED + POLL_INTERVAL))

        if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
            echo "[!] Timeout (${TIMEOUT}s) waiting for VPN — tunnel may not be up."
            return 1
        fi

        printf "\r[*] Still waiting... (%ds elapsed)" "$ELAPSED"
    done
}

# Print the tun0 interface address once VPN is confirmed up
_print_vpn_interface() {
    local TUN_IP
    TUN_IP=$(ip -4 addr show tun0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    if [[ -n "$TUN_IP" ]]; then
        echo "[+] tun0 address : $TUN_IP"
    else
        echo "[*] tun0 not yet visible — OpenVPN may still be configuring routes."
    fi
}

# check_vpn_status — quick status check, non-blocking
check_vpn_status() {
    if ip link show tun0 &>/dev/null; then
        local TUN_IP
        TUN_IP=$(ip -4 addr show tun0 | awk '/inet /{print $2}' | cut -d/ -f1)
        echo "[+] VPN UP — tun0: $TUN_IP"
        return 0
    else
        echo "[!] VPN DOWN — tun0 not present."
        return 1
    fi
}
