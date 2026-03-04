#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V3 — modules/recon.sh
# Standalone helpers for manual use from any terminal.
# sentinel.sh no longer calls these — it builds scripts directly.
# ============================================================

# Usage: run_nmap <TARGET_IP> [OUTPUT_FILE]
run_nmap() {
    local IP="$1"
    local OUT="${2:-nmap/initial.txt}"
    echo "[*] RustScan -> Nmap | $IP"
    if command -v rustscan &>/dev/null; then
        rustscan -a "$IP" --ulimit 5000 --timeout 3000 --batch-size 500 -- -A -sC -oN "$OUT" 2>&1
    else
        nmap -A -sC -sV -oN "$OUT" "$IP"
    fi
}

# Usage: run_ffuf <TARGET_IP> [WORDLIST]
run_ffuf() {
    local IP="$1"
    local WL="${2:-$HOME/Desktop/wordlists/dirb/common.txt}"
    echo "[*] FFUF | http://$IP/FUZZ"
    ffuf -w "$WL" -u "http://$IP/FUZZ" -s -mc 200,301,302,403 -c
}
