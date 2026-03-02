#!/bin/bash
# ============================================================
# Bosatek Sentinel - Network Module
# Usage: network.sh [vpn|burp] [ROOM_DIR] [ROOM_NAME]
# ============================================================

ACTION="${1}"
ROOM_DIR="${2}"
ROOM_NAME="${3}"

start_vpn() {
    echo "[+] ===== Starting OpenVPN (TryHackMe) ====="
    sudo openvpn ~/Documents/THM.ovpn
}

start_burp() {
    echo "[+] ===== Launching Burp Suite Pro | Project: $ROOM_NAME ====="
    mkdir -p "$ROOM_DIR/burp"
    burp --project-file="$ROOM_DIR/burp/$ROOM_NAME.burp"
}

case "$ACTION" in
    vpn)
        start_vpn
        ;;
    burp)
        start_burp
        ;;
    *)
        echo "[!] Usage: network.sh [vpn|burp] [ROOM_DIR] [ROOM_NAME]"
        exit 1
        ;;
esac
