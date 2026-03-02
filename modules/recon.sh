#!/bin/bash
# ============================================================
# Bosatek Sentinel - Recon Module
# Usage: recon.sh [scan|ffuf] <TARGET_IP> <ROOM_DIR>
# ============================================================

ACTION="${1}"
TARGET_IP="${2}"
ROOM_DIR="${3}"

run_scan() {
    echo "[+] ===== RustScan -> Nmap | Target: $TARGET_IP ====="
    rustscan -a "$TARGET_IP" --ulimit 5000 -- -A -sC -sV -oN "$ROOM_DIR/nmap/initial.txt"
    echo "[+] Nmap scan complete. Results saved to $ROOM_DIR/nmap/initial.txt"
}

run_ffuf() {
    echo "[+] ===== FFUF Directory Brute-Force | Target: $TARGET_IP ====="
    mkdir -p "$ROOM_DIR/ffuf"
    ffuf \
        -w ~/Desktop/wordlists/dirb/common.txt \
        -u "http://$TARGET_IP/FUZZ" \
        -e .php,.html,.txt \
        -t 100 \
        -o "$ROOM_DIR/ffuf/hits.json"
    echo "[+] FFUF complete. Results saved to $ROOM_DIR/ffuf/hits.json"
}

case "$ACTION" in
    scan)
        run_scan
        ;;
    ffuf)
        run_ffuf
        ;;
    *)
        echo "[!] Usage: recon.sh [scan|ffuf] <TARGET_IP> <ROOM_DIR>"
        exit 1
        ;;
esac
