#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V3 — modules/recon.sh  (MVP build)
# Called directly from tmux panes in Tab 1 [Recon].
# No AI Brain references.
# ============================================================

# run_nmap <TARGET_IP> <OUTPUT_FILE|/dev/null>
# RustScan → Nmap pass-through. Falls back to plain Nmap if needed.
# Slow-Wi-Fi flags: --timeout 3000 --batch-size 500
run_nmap() {
    local TARGET_IP="$1"
    local NMAP_OUT="${2:-/dev/null}"

    echo "============================================"
    echo " PORT SCAN — $TARGET_IP"
    echo " $(date)"
    echo "============================================"
    echo ""

    if command -v rustscan &>/dev/null; then
        echo "[*] RustScan → Nmap (-A -sC)"
        echo "[*] Flags: --timeout 3000 --batch-size 500"
        echo ""
        rustscan -a "$TARGET_IP" \
            --ulimit 5000 \
            --timeout 3000 \
            --batch-size 500 \
            -- -A -sC -oN "$NMAP_OUT" 2>&1
    else
        echo "[!] RustScan not found — using Nmap directly."
        echo ""
        nmap -A -sC -sV -oN "$NMAP_OUT" "$TARGET_IP"
    fi

    echo ""
    echo "[+] Port scan complete."
    [[ "$NMAP_OUT" != "/dev/null" ]] && echo "[+] Saved → $NMAP_OUT"
    echo ""
    echo "[*] Press Enter to reuse this pane."
    read -r
}

# run_ffuf <TARGET_IP> <OUTPUT_FILE|""> <WORDLIST>
# FFUF with -s (silent, no progress bar) and -mc 200,301,302,403.
# Pass an empty string for OUTPUT_FILE to skip saving (volatile mode).
run_ffuf() {
    local TARGET_IP="$1"
    local FFUF_OUT="$2"
    local WORDLIST="${3:-$HOME/Desktop/wordlists/dirb/common.txt}"

    echo "============================================"
    echo " WEB FUZZ — http://$TARGET_IP/FUZZ"
    echo " $(date)"
    echo "============================================"
    echo ""

    if ! command -v ffuf &>/dev/null; then
        echo "[!] ffuf not installed — skipping."
        echo "[*] Press Enter to reuse this pane."
        read -r; return 1
    fi

    if [[ ! -f "$WORDLIST" ]]; then
        echo "[!] Wordlist not found: $WORDLIST"
        echo "[!] Set WORDLIST env var or place wordlist at that path."
        echo "[*] Press Enter to reuse this pane."
        read -r; return 1
    fi

    echo "[*] Wordlist : $WORDLIST"
    echo "[*] Target   : http://$TARGET_IP/FUZZ"
    echo "[*] Flags    : -s -mc 200,301,302,403"
    echo ""

    # -s              : silent — no banner, no progress bar
    # -mc 200,301,302,403 : show ONLY these status codes
    if [[ -n "$FFUF_OUT" ]]; then
        ffuf -w "$WORDLIST" \
             -u "http://$TARGET_IP/FUZZ" \
             -s \
             -mc 200,301,302,403 \
             -o "$FFUF_OUT" \
             -of csv
    else
        ffuf -w "$WORDLIST" \
             -u "http://$TARGET_IP/FUZZ" \
             -s \
             -mc 200,301,302,403
    fi

    echo ""
    echo "[+] FFUF complete."
    [[ -n "$FFUF_OUT" ]] && echo "[+] Saved → $FFUF_OUT"
    echo ""
    echo "[*] Press Enter to reuse this pane."
    read -r
}
